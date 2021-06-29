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
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/Layer.h"
#include "llvm/ExecutionEngine/Orc/Shared/FDRawByteChannel.h"
#include "llvm/Support/Error.h"

#include <memory>
#include <string>

namespace llvm {
namespace orc {

/// Find the default llvm-jitlink-executor on disk.
std::string findLocalExecutor(const char *HostArgv0);

/// Launch the executor form the given path in a subprocess. On success this
/// returns a pipe and the ID of the new process.
Expected<std::pair<std::unique_ptr<shared::FDRawByteChannel>, uint32_t>>
launchLocalExecutor(StringRef ExecutablePath);

/// Establish a TCP connection to the given network address,
/// e.g. localhost:20000.
Expected<std::unique_ptr<shared::FDRawByteChannel>>
connectTCPSocket(StringRef NetworkAddress);

/// Add the DebugObjectManagerPlugin to the given ObjectLinkingLayer.
Error addDebugSupport(ObjectLayer &ObjLinkingLayer);

/// Load a dynamic library from the given path on the remote host.
Expected<std::unique_ptr<DefinitionGenerator>>
loadDylib(ExecutionSession &ES, StringRef RemotePath);

/// Create an RPC stub that allows the JIT to control the target process on the remote host.
Expected<std::unique_ptr<TargetProcessControl>>
createRemoteTargetProcessControl(std::unique_ptr<shared::FDRawByteChannel> Channel,
                                 unique_function<void(Error)> ReportError);

} // namespace orc
} // namespace llvm

#endif
