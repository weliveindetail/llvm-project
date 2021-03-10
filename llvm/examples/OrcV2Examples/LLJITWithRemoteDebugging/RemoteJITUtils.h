//===-- RemoteJITUtils.h - Utilities for remote-JITing ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Utilities for TargetProcessControl-based remote JITing with Orc and JITLink.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXAMPLES_ORCV2EXAMPLES_LLJITWITHREMOTEDEBUGGING_REMOTEJITUTILS_H
#define LLVM_EXAMPLES_ORCV2EXAMPLES_LLJITWITHREMOTEDEBUGGING_REMOTEJITUTILS_H

#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/Orc/Shared/FDRawByteChannel.h"
#include "llvm/ExecutionEngine/Orc/OrcRPCTargetProcessControl.h"
#include "llvm/ExecutionEngine/Orc/Shared/RPCUtils.h"
#include "llvm/Support/Error.h"

#include <memory>
#include <string>

#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#else
#include <io.h>
#endif

namespace llvm {
namespace orc {

class JITLinkExecutor {
public:
  using RPCChannel = shared::FDRawByteChannel;

  static Expected<JITLinkExecutor> Create(std::string ExecutablePath);
  static Expected<JITLinkExecutor> Find(const char *JITArgv0);

  Expected<std::unique_ptr<RPCChannel>> launch();

  StringRef getPath() const { return ExecutablePath; }
  pid_t getPID() const { return ProcessID; }

private:
  std::string ExecutablePath;
  pid_t ProcessID;

  JITLinkExecutor(std::string ExecutablePath) : ExecutablePath(std::move(ExecutablePath)) {}

  static std::string defaultPath(const char *JITArgv0, StringRef ExecutorName);
};

class RemoteTargetProcessControl
    : public OrcRPCTargetProcessControlBase<
        shared::MultiThreadedRPCEndpoint<JITLinkExecutor::RPCChannel>> {

  using ThisT = RemoteTargetProcessControl;
  using MemoryAccess = OrcRPCTPCMemoryAccess<ThisT>;
  using MemoryManager = OrcRPCTPCJITLinkMemoryManager<ThisT>;

  using RPCChannel = JITLinkExecutor::RPCChannel;
  using RPCEndpoint = shared::MultiThreadedRPCEndpoint<RPCChannel>;
  using BaseT = OrcRPCTargetProcessControlBase<RPCEndpoint>;

public:
  static Expected<std::unique_ptr<ThisT>>
  Create(ExecutionSession &ES, std::unique_ptr<RPCChannel> Channel);

private:
  RemoteTargetProcessControl(
      std::shared_ptr<SymbolStringPool> SSP,
      std::unique_ptr<RPCChannel> Channel,
      std::unique_ptr<RPCEndpoint> Endpoint,
      ErrorReporter ReportError);

  void initializeMemoryManagement();
  Error disconnect() override;

  std::unique_ptr<RPCChannel> Channel;
  std::unique_ptr<RPCEndpoint> Endpoint;
  std::unique_ptr<MemoryAccess> OwnedMemAccess;
  std::unique_ptr<MemoryManager> OwnedMemMgr;
  std::atomic<bool> Finished{false};
  std::thread ListenerThread;
};

}
}

#endif
