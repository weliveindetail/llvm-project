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

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Triple.h"
#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/Layer.h"
#include "llvm/ExecutionEngine/Orc/OrcRPCTargetProcessControl.h"
#include "llvm/ExecutionEngine/Orc/ObjectTransformLayer.h"
#include "llvm/ExecutionEngine/Orc/Shared/FDRawByteChannel.h"
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

using ChannelT = shared::FDRawByteChannel;
using EndpointT = shared::MultiThreadedRPCEndpoint<ChannelT>;

/// Find the default exectuable on disk and create a JITLinkExecutor for it.
std::string findLocalExecutor(const char *HostArgv0);

Expected<std::pair<std::unique_ptr<ChannelT>, pid_t>>
launchLocalExecutor(StringRef ExecutablePath);

/// Create a JITLinkExecutor that connects to the given network address
/// through a TCP socket. A valid NetworkAddress provides hostname and port,
/// e.g. localhost:20000.
Expected<std::unique_ptr<ChannelT>>
connectTCPSocket(StringRef NetworkAddress);

Error addDebugSupport(ObjectLayer &ObjLayer);

Expected<std::unique_ptr<DefinitionGenerator>>
loadDylib(ExecutionSession &ES, StringRef RemotePath);

using ErrorReporterT = unique_function<void(Error)>;

class RemoteTargetProcessControl
    : public OrcRPCTargetProcessControlBase<
          shared::MultiThreadedRPCEndpoint<ChannelT>> {
private:
  using ThisT = RemoteTargetProcessControl;
  using BaseT = OrcRPCTargetProcessControlBase<EndpointT>;
  using MemoryAccessT = OrcRPCTPCMemoryAccess<ThisT>;
  using MemoryManagerT = OrcRPCTPCJITLinkMemoryManager<ThisT>;

public:
  RemoteTargetProcessControl(std::unique_ptr<ChannelT> Channel,
                             ErrorReporter ReportError);
  ~RemoteTargetProcessControl();

  void initializeMemoryManagement();

private:
  std::unique_ptr<ChannelT> Channel;
  std::unique_ptr<EndpointT> Endpoint;
  std::unique_ptr<MemoryAccessT> OwnedMemAccess;
  std::unique_ptr<MemoryManagerT> OwnedMemMgr;
  std::atomic<bool> Finished{false};
  std::thread ListenerThread;

  Error disconnect() override;
};

} // namespace orc
} // namespace llvm

#endif
