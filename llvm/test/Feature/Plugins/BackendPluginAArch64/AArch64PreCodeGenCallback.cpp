//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This is a self-contained plugin that embeds its own, statically-linked
// copy of the AArch64 backend, built independently of whatever target(s) the
// host tool itself was built with. Its PreCodeGenCallback ignores the
// TargetMachine handed in by the host and instead compiles the module for
// AArch64, replacing the host's backend entirely.
//
// Every symbol except the plugin entry point is localized at link time (see
// BackendPluginAArch64.exports): this plugin's private copies of the
// cl::opt/TargetRegistry/PassRegistry singletons it pulls in transitively
// must never merge with the host's. That isolation is also why this plugin
// cannot register anything into the host's own pipeline the way CGTestPlugin
// does -- it can only run its own, fully private one.
//
// The same isolation creates a subtler hazard for APFloat: fltSemantics
// objects (APFloat::IEEEdouble() and friends) are plain statics, and several
// APFloat/Type APIs (SemanticsToEnum, IEEEFloat::bitcastToAPInt, ...)
// identify a format by comparing its fltSemantics *address*, not its value.
// A ConstantFP built by the host (e.g. while parsing the input IR) carries a
// pointer to the host's copy of that static; once this plugin's own,
// isolated copy of APFloat.cpp looks at the same value, every one of those
// address comparisons fails even though the bit layout is identical. Left
// to run into that on its own, this plugin would hit it inside AsmPrinter
// while emitting apfloat_probe's initializer, as an assertion failure deep
// in IEEEFloat::bitcastToAPInt ("unknown format!") in assertions-enabled
// builds, or unspecified behavior otherwise -- neither of which makes a
// good, portable regression check. probeAPFloatIdentity() below instead
// demonstrates the same underlying mismatch directly and reports it as a
// plain diagnostic, then preCodeGenCallback() returns before codegen ever
// reaches the mismatched constant.
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/Constants.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Target/TargetMachine.h"

using namespace llvm;

namespace {

// Looks for a global `double` variable named `apfloat_probe`. If present,
// reports whether its ConstantFP's fltSemantics is the *same object* as
// this plugin's own, statically-linked APFloat::IEEEdouble() -- see the file
// comment above -- and returns true so the caller stops before codegen ever
// touches the (potentially mismatched) constant.
bool probeAPFloatIdentity(Module &M) {
  auto *GV = M.getGlobalVariable("apfloat_probe");
  if (!GV || !GV->hasInitializer())
    return false;
  auto *CFP = dyn_cast<ConstantFP>(GV->getInitializer());
  if (!CFP)
    return false;

  const fltSemantics &HostSem = CFP->getValueAPF().getSemantics();
  bool SameAddress = &HostSem == &APFloat::IEEEdouble();
  outs() << "BackendPluginAArch64: apfloat_probe semantics address is "
         << (SameAddress ? "the SAME as" : "DIFFERENT from")
         << " this plugin's own APFloat::IEEEdouble()\n";
  outs().flush();
  return true;
}

bool preCodeGenCallback(Module &M, TargetMachine &, CodeGenFileType CGFT,
                        raw_pwrite_stream &OS) {
  // Comment this to reproduce the real APFloat crash
  if (probeAPFloatIdentity(M))
    return true;

  LLVMInitializeAArch64TargetInfo();
  LLVMInitializeAArch64Target();
  LLVMInitializeAArch64TargetMC();
  LLVMInitializeAArch64AsmPrinter();

  Triple TT("aarch64-unknown-linux-gnu");
  std::string Error;
  const Target *TheTarget = TargetRegistry::lookupTarget(TT, Error);
  if (!TheTarget) {
    M.getContext().emitError("BackendPluginAArch64: " + Error);
    return false;
  }

  TargetOptions Options;
  Options.MCOptions.AsmVerbose = true;
  std::unique_ptr<TargetMachine> TM(TheTarget->createTargetMachine(
      TT, /*CPU=*/"", /*Features=*/"", Options, /*RM=*/std::nullopt));
  if (!TM) {
    M.getContext().emitError(
        "BackendPluginAArch64: failed to create AArch64 target machine");
    return false;
  }

  // Replace whatever the host tool selected: compile for AArch64 regardless.
  M.setTargetTriple(TT);
  M.setDataLayout(TM->createDataLayout());

  legacy::PassManager PM;
  if (TM->addPassesToEmitFile(PM, OS, /*DwoOut=*/nullptr, CGFT)) {
    M.getContext().emitError(
        "BackendPluginAArch64: AArch64 backend cannot emit this file type");
    return false;
  }

  PM.run(M);
  return true; // Signal Done: this replaces the built-in backend entirely.
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "BackendPluginAArch64", LLVM_VERSION_STRING,
          nullptr, preCodeGenCallback};
}
