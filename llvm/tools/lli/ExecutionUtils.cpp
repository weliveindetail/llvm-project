//===---- ExecutionUtils.cpp - Utilities for executing functions in lli ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "ExecutionUtils.h"

#include "llvm/Support/FileSystem.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/raw_ostream.h"

#include <cstdint>
#include <vector>

// Declarations follow the GDB JIT interface (version 1, 2009) and must match
// those of the DYLD used for testing. See:
//
//   llvm/lib/ExecutionEngine/Orc/TargetProcess/JITLoaderGDB.cpp
//   llvm/lib/ExecutionEngine/GDBRegistrationListener.cpp
//
typedef enum {
  JIT_NOACTION = 0,
  JIT_REGISTER_FN,
  JIT_UNREGISTER_FN
} jit_actions_t;

struct jit_code_entry {
  struct jit_code_entry *next_entry;
  struct jit_code_entry *prev_entry;
  const char *symfile_addr;
  uint64_t symfile_size;
};

struct jit_descriptor {
  uint32_t version;
  // This should be jit_actions_t, but we want to be specific about the
  // bit-width.
  uint32_t action_flag;
  struct jit_code_entry *relevant_entry;
  struct jit_code_entry *first_entry;
};

namespace llvm {

template <typename... Ts> static void outsv(const char *Fmt, Ts &&...Vals) {
  outs() << formatv(Fmt, Vals...);
}

static const char *actionFlagToStr(uint32_t ActionFlag) {
  switch (ActionFlag) {
  case JIT_NOACTION:
    return "JIT_NOACTION";
  case JIT_REGISTER_FN:
    return "JIT_REGISTER_FN";
  case JIT_UNREGISTER_FN:
    return "JIT_UNREGISTER_FN";
  }
  return "<invalid action_flag>";
}

// Sample output:
//
//   Reading __jit_debug_descriptor at 0x0000000000404048
//
//   Version: 0
//   Action: JIT_REGISTER_FN
//
//         Entry               Symbol File         Size  Previous Entry
//   [ 0]  0x0000000000451290  0x0000000000002000   200  0x0000000000000000
//   [ 1]  0x0000000000451260  0x0000000000001000   100  0x0000000000451290
//   ...
//
static void dumpDebugDescriptor(void *Addr) {
  outsv("Reading __jit_debug_descriptor at {0}\n\n", Addr);

  jit_descriptor *Descriptor = reinterpret_cast<jit_descriptor *>(Addr);
  outsv("Version: {0}\n", Descriptor->version);
  outsv("Action: {0}\n\n", actionFlagToStr(Descriptor->action_flag));
  outsv("{0,11}  {1,24}  {2,15}  {3,14}\n", "Entry", "Symbol File", "Size",
        "Previous Entry");

  unsigned Idx = 0;
  for (auto *Entry = Descriptor->first_entry; Entry; Entry = Entry->next_entry)
    outsv("[{0,2}]  {1:X16}  {2:X16}  {3,8:D}  {4}\n", Idx++, Entry,
          reinterpret_cast<const void *>(Entry->symfile_addr),
          Entry->symfile_size, Entry->prev_entry);
}

static LLIBuiltinFunctionGenerator *Generator = nullptr;

static void dumpDebugObjects(void *Addr) {
  jit_descriptor *Descriptor = reinterpret_cast<jit_descriptor *>(Addr);
  for (auto *Entry = Descriptor->first_entry; Entry; Entry = Entry->next_entry)
    Generator->appendDebugObject(Entry->symfile_addr, Entry->symfile_size);
}

LLIBuiltinFunctionGenerator::LLIBuiltinFunctionGenerator(
    std::vector<BuiltinFunctionKind> Enabled, orc::MangleAndInterner &Mangle)
    : TestOut(nullptr) {
  Generator = this;
  for (BuiltinFunctionKind F : Enabled) {
    switch (F) {
    case BuiltinFunctionKind::DumpDebugDescriptor:
      expose(Mangle("__dump_jit_debug_descriptor"), &dumpDebugDescriptor);
      break;
    case BuiltinFunctionKind::DumpDebugObjects:
      expose(Mangle("__dump_jit_debug_objects"), &dumpDebugObjects);
      TestOut = createToolOutput();
      break;
    }
  }
}

Error LLIBuiltinFunctionGenerator::tryToGenerate(
    orc::LookupState &LS, orc::LookupKind K, orc::JITDylib &JD,
    orc::JITDylibLookupFlags JDLookupFlags,
    const orc::SymbolLookupSet &Symbols) {
  orc::SymbolMap NewSymbols;
  for (const auto &NameFlags : Symbols) {
    auto It = BuiltinFunctions.find(NameFlags.first);
    if (It != BuiltinFunctions.end())
      NewSymbols.insert(*It);
  }

  if (NewSymbols.empty())
    return Error::success();

  return JD.define(absoluteSymbols(std::move(NewSymbols)));
}

// static
std::unique_ptr<ToolOutputFile>
LLIBuiltinFunctionGenerator::createToolOutput() {
  std::error_code EC;
  auto TestOut = std::make_unique<ToolOutputFile>("-", EC, sys::fs::OF_None);
  if (EC) {
    errs() << "Error creating tool output file: " << EC.message() << '\n';
    exit(1);
  }
  return TestOut;
}



LLIRemoteTargetProcessControl::LLIRemoteTargetProcessControl(
    std::unique_ptr<LLIRPCChannel> Channel,
    std::unique_ptr<LLIRPCEndpoint> Endpoint,
    ErrorReporter ReportError)
    : BaseT(std::make_shared<orc::SymbolStringPool>(), *Endpoint,
            std::move(ReportError)),
      Channel(std::move(Channel)), Endpoint(std::move(Endpoint)) {

  ListenerThread = std::thread([&]() {
    while (!Finished) {
      if (auto Err = this->Endpoint->handleOne()) {
        reportError(std::move(Err));
        return;
      }
    }
  });
}

// static
Error LLIRemoteTargetProcessControl::checkPlatformSupported(Triple &TT) {
  Triple::ArchType Arch = TT.getArch();
  if (TT.isOSBinFormatELF()) {
    if (Arch != Triple::x86_64)
      return make_error<StringError>(
          "Out-of-process execution for ELF only supported on x86-64 targets",
          inconvertibleErrorCode());
  }
  if (TT.isOSBinFormatMachO()) {
    if (Arch != Triple::aarch64 && Arch != Triple::x86_64)
      return make_error<StringError>(
          "Out-of-process execution for MachO only supported on ARM64 and "
          "x86-64 targets",
          inconvertibleErrorCode());
  }
  return Error::success();
}

// static
Expected<std::unique_ptr<LLIRemoteTargetProcessControl>>
LLIRemoteTargetProcessControl::Create(orc::ExecutionSession &ES,
                                      std::unique_ptr<LLIRPCChannel> Channel) {
  auto Endpoint = std::make_unique<LLIRPCEndpoint>(*Channel, true);
  std::unique_ptr<LLIRemoteTargetProcessControl> TPC(
      new LLIRemoteTargetProcessControl(
          std::move(Channel), std::move(Endpoint),
          [&ES](Error Err) { ES.reportError(std::move(Err)); }));

  if (auto Err = TPC->initializeORCRPCTPCBase())
    return joinErrors(std::move(Err), TPC->disconnect());

  TPC->initializeMemoryManagement();
  return std::move(TPC);
}

void LLIRemoteTargetProcessControl::initializeMemoryManagement() {
  OwnedMemAccess = std::make_unique<MemoryAccess>(*this);
  OwnedMemMgr = std::make_unique<MemoryManager>(*this);

  // Base class needs non-owning access.
  MemAccess = OwnedMemAccess.get();
  MemMgr = OwnedMemMgr.get();
}

Error LLIRemoteTargetProcessControl::disconnect() {
  std::promise<MSVCPError> P;
  auto F = P.get_future();
  auto Err = closeConnection([&](Error Err) -> Error {
    P.set_value(std::move(Err));
    Finished = true;
    return Error::success();
  });
  ListenerThread.join();
  return joinErrors(std::move(Err), F.get());
}


} // namespace llvm
