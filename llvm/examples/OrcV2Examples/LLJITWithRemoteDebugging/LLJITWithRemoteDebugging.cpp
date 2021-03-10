//===--- LLJITWithRemoteDebugging.cpp - LLJIT targeting a child process ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// In this example we will execute JITed code in a child process:
//
// 1. Launch a remote process.
// 2. Create a JITLink-compatible remote memory manager.
// 3. Use LLJITBuilder to create a (greedy) LLJIT instance.
// 4. Add the Add1Example module and execute add1().
// 5. Terminate the remote target session.
//
//===----------------------------------------------------------------------===//

#include "llvm/ExecutionEngine/Orc/DebugObjectManagerPlugin.h"
#include "llvm/ExecutionEngine/Orc/JITTargetMachineBuilder.h"
#include "llvm/ExecutionEngine/Orc/LLJIT.h"
#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"
#include "llvm/ExecutionEngine/Orc/TPCDebugObjectRegistrar.h"
#include "llvm/ExecutionEngine/Orc/TargetProcess/JITLoaderGDB.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"

#include "../ExampleModules.h"
#include "RemoteJITUtils.h"

#include <memory>
#include <string>

#define DEBUG_TYPE "orc"

using namespace llvm;
using namespace llvm::orc;

static cl::opt<std::string> InputFile(
    cl::desc("<input IR code>"), cl::Positional, cl::init("-"));

// File path of the executable to use for remote execution. The child process
// will be executed and prepared for communication via stdin/stdout pipes.
static cl::opt<std::string> OutOfProcessExecutor(
    "oop-executor", cl::desc("Set the out-of-process executor"),
    cl::value_desc("filename"), cl::ValueOptional);

static cl::opt<bool> WaitForDebugger("wait-for-debugger",
    cl::desc("Wait for user input before entering JITed code"),
    cl::init(false));

int main(int argc, char *argv[]) {
  InitLLVM X(argc, argv);

  InitializeNativeTarget();
  InitializeNativeTargetAsmPrinter();

  cl::ParseCommandLineOptions(argc, argv, "LLJITWithRemoteDebugging");

  ExitOnError ExitOnErr;
  ExitOnErr.setBanner(std::string(argv[0]) + ": ");

  // Load the given IR module
  ThreadSafeModule TSM = ExitOnErr(parseExampleModuleFromFile(InputFile));

  // Launch the remote process, get a channel to it and give the user a chance
  // to attach a debugger.
  JITLinkExecutor Executor = ExitOnErr(
      OutOfProcessExecutor.empty() ? JITLinkExecutor::Find(argv[0])
                                   : JITLinkExecutor::Create(OutOfProcessExecutor));

  std::unique_ptr<JITLinkExecutor::RPCChannel> Channel = ExitOnErr(Executor.launch());

  if (WaitForDebugger) {
    outs() << "Executor launched in subprocess " << Executor.getPID()
           << ": " << Executor.getPath() << "\n"
           << "Attach a debugger and press any key to continue.\n";
    fflush(stdin);
    getchar();
  }

  // Launch the remote process and initialize TPC for it.
  auto ES = std::make_unique<ExecutionSession>();
  ES->setErrorReporter([&](Error Err) { ExitOnErr(std::move(Err)); });

  std::unique_ptr<orc::TargetProcessControl> TPC =
      ExitOnErr(RemoteTargetProcessControl::Create(*ES, std::move(Channel)));

  // Created target machine should match the triple of the given module.
  JITTargetMachineBuilder JTMB(Triple(TSM.getModuleUnlocked()->getTargetTriple()));
  JTMB.setCodeModel(CodeModel::Small);
  JTMB.setRelocationModel(Reloc::PIC_);

  // Create an LLJIT instance with a JITLink ObjectLinkingLayer and destroy it
  // before we disconnect the target process.
  {
    auto J = ExitOnErr(
        LLJITBuilder()
            .setExecutionSession(std::move(ES))
            .setJITTargetMachineBuilder(std::move(JTMB))
            .setTargetProcessControl(*TPC)
            .setObjectLinkingLayerCreator(
                [&](ExecutionSession &ES, const Triple &TT) {
                  return std::make_unique<ObjectLinkingLayer>(ES, TPC->getMemMgr());
                })
            .create());

    // Add the plugin that injects debug support.
    auto *ObjLayer = cast<ObjectLinkingLayer>(&J->getObjLinkingLayer());
    ObjLayer->addPlugin(std::make_unique<DebugObjectManagerPlugin>(
        J->getExecutionSession(), ExitOnErr(createJITLoaderGDBRegistrar(*TPC))));

    // Add the given IR code to the JIT.
    ExitOnErr(J->addIRModule(std::move(TSM)));

    // Materialize the code by looking up the main function. It also triggers
    // debug registration in the remote target process.
    JITEvaluatedSymbol MainFn = ExitOnErr(J->lookup("main"));

    // Run the code in the remote target process and dump the result.
    int Result = ExitOnErr(TPC->runAsMain(MainFn.getAddress(), { "" }));
    outs() << "sub1(2) = " << Result << "\n";
  }

  ExitOnErr(TPC->disconnect());
  return 0;
}
