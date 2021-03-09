//===- ExecutionUtils.h - Utilities for executing code in lli ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Contains utilities for executing code in lli.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TOOLS_LLI_EXECUTIONUTILS_H
#define LLVM_TOOLS_LLI_EXECUTIONUTILS_H

#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/Mangling.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ToolOutputFile.h"

#include "llvm/ExecutionEngine/Orc/OrcRPCTargetProcessControl.h"
#include "llvm/ExecutionEngine/Orc/Shared/FDRawByteChannel.h"
#include "llvm/ExecutionEngine/Orc/Shared/RPCUtils.h"

#include <memory>
#include <thread>
#include <utility>

namespace llvm {

enum class BuiltinFunctionKind {
  DumpDebugDescriptor,
  DumpDebugObjects,
};

// Utility class to expose symbols for special-purpose functions to the JIT.
class LLIBuiltinFunctionGenerator : public orc::DefinitionGenerator {
public:
  LLIBuiltinFunctionGenerator(std::vector<BuiltinFunctionKind> Enabled,
                              orc::MangleAndInterner &Mangle);

  Error tryToGenerate(orc::LookupState &LS, orc::LookupKind K,
                      orc::JITDylib &JD, orc::JITDylibLookupFlags JDLookupFlags,
                      const orc::SymbolLookupSet &Symbols) override;

  void appendDebugObject(const char *Addr, size_t Size) {
    TestOut->os().write(Addr, Size);
  }

private:
  orc::SymbolMap BuiltinFunctions;
  std::unique_ptr<ToolOutputFile> TestOut;

  template <typename T> void expose(orc::SymbolStringPtr Name, T *Handler) {
    BuiltinFunctions[Name] = JITEvaluatedSymbol(
        pointerToJITTargetAddress(Handler), JITSymbolFlags::Exported);
  }

  static std::unique_ptr<ToolOutputFile> createToolOutput();
};

using LLIRPCChannel = orc::shared::FDRawByteChannel;
using LLIRPCEndpoint =
    orc::shared::MultiThreadedRPCEndpoint<LLIRPCChannel>;

class LLIRemoteTargetProcessControl
    : public orc::OrcRPCTargetProcessControlBase<LLIRPCEndpoint> {

  using ThisT = LLIRemoteTargetProcessControl;
  using BaseT = orc::OrcRPCTargetProcessControlBase<LLIRPCEndpoint>;
  using MemoryAccess = orc::OrcRPCTPCMemoryAccess<ThisT>;
  using MemoryManager = orc::OrcRPCTPCJITLinkMemoryManager<ThisT>;

public:
  static Error checkPlatformSupported(Triple &TT);

  static Expected<std::unique_ptr<ThisT>>
  Create(orc::ExecutionSession &ES, std::unique_ptr<LLIRPCChannel> Channel);

private:
  LLIRemoteTargetProcessControl(
      std::shared_ptr<orc::SymbolStringPool> SSP,
      std::unique_ptr<LLIRPCChannel> Channel,
      std::unique_ptr<LLIRPCEndpoint> Endpoint,
      ErrorReporter ReportError);

  void initializeMemoryManagement();
  Error disconnect() override;

  std::unique_ptr<LLIRPCChannel> Channel;
  std::unique_ptr<LLIRPCEndpoint> Endpoint;
  std::unique_ptr<MemoryAccess> OwnedMemAccess;
  std::unique_ptr<MemoryManager> OwnedMemMgr;
  std::atomic<bool> Finished{false};
  std::thread ListenerThread;
};

} // end namespace llvm

#endif // LLVM_TOOLS_LLI_EXECUTIONUTILS_H
