//===-- RemoteJITUtils.cpp - Utilities for remote-JITing --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RemoteJITUtils.h"

#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/DebugObjectManagerPlugin.h"
#include "llvm/ExecutionEngine/Orc/OrcRPCTargetProcessControl.h"
#include "llvm/ExecutionEngine/Orc/Shared/RPCUtils.h"
#include "llvm/ExecutionEngine/Orc/TPCDebugObjectRegistrar.h"
#include "llvm/ExecutionEngine/Orc/TPCDynamicLibrarySearchGenerator.h"
#include "llvm/ExecutionEngine/Orc/TargetProcess/JITLoaderGDB.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"

#ifdef LLVM_ON_UNIX
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#else
#include <io.h>
#endif // LLVM_ON_UNIX

namespace llvm {
namespace orc {

using ChannelT = shared::FDRawByteChannel;
using EndpointT = shared::MultiThreadedRPCEndpoint<ChannelT>;

class RemoteTargetProcessControl
    : public OrcRPCTargetProcessControlBase<
          shared::MultiThreadedRPCEndpoint<ChannelT>> {
private:
  using ThisT = RemoteTargetProcessControl;
  using BaseT = OrcRPCTargetProcessControlBase<EndpointT>;
  using MemoryAccessT = OrcRPCTPCMemoryAccess<ThisT>;
  using MemoryManagerT = OrcRPCTPCJITLinkMemoryManager<ThisT>;

public:
  RemoteTargetProcessControl(std::unique_ptr<ChannelT> Channel, std::unique_ptr<EndpointT> Endpoint,
                             ErrorReporter ReportError);
  ~RemoteTargetProcessControl();

  using BaseT::initializeORCRPCTPCBase;
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

RemoteTargetProcessControl::RemoteTargetProcessControl(
    std::unique_ptr<ChannelT> Channel, std::unique_ptr<EndpointT> Endpoint,
    ErrorReporter ReportError)
    : BaseT(std::make_shared<SymbolStringPool>(), *Endpoint, std::move(ReportError)),
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

RemoteTargetProcessControl::~RemoteTargetProcessControl() {
  if (Error Err = disconnect())
    reportError(std::move(Err));
}

void RemoteTargetProcessControl::initializeMemoryManagement() {
  OwnedMemAccess = std::make_unique<MemoryAccessT>(*this);
  OwnedMemMgr = std::make_unique<MemoryManagerT>(*this);

  // Base class needs non-owning access.
  MemAccess = OwnedMemAccess.get();
  MemMgr = OwnedMemMgr.get();
}

Error RemoteTargetProcessControl::disconnect() {
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

Expected<std::unique_ptr<TargetProcessControl>>
createRemoteTargetProcessControl(std::unique_ptr<shared::FDRawByteChannel> Channel,
                                 unique_function<void(Error)> ReportError) {
  auto EP = std::make_unique<EndpointT>(*Channel, true);
  auto TPC = std::make_unique<RemoteTargetProcessControl>(std::move(Channel), std::move(EP), std::move(ReportError));

  if (auto Err = TPC->initializeORCRPCTPCBase())
    return std::move(Err);

  TPC->initializeMemoryManagement();
  shared::registerStringError<ChannelT>();
  return std::move(TPC);
}

Error addDebugSupport(ObjectLayer &ObjLayer) {
  ExecutionSession &ES = ObjLayer.getExecutionSession();
  auto Registrar = createJITLoaderGDBRegistrar(ES);
  if (!Registrar)
    return Registrar.takeError();

  auto *ObjLinkingLayer = cast<ObjectLinkingLayer>(&ObjLayer);
  if (!ObjLinkingLayer)
    return createStringError(inconvertibleErrorCode(),
                             "No debug support for given object layer type");

  ObjLinkingLayer->addPlugin(
      std::make_unique<DebugObjectManagerPlugin>(ES, std::move(*Registrar)));
  return Error::success();
}

Expected<std::unique_ptr<DefinitionGenerator>>
loadDylib(ExecutionSession &ES, StringRef RemotePath) {
  if (auto Handle = ES.getTargetProcessControl().loadDylib(RemotePath.data()))
    return std::make_unique<TPCDynamicLibrarySearchGenerator>(ES, *Handle);
  else
    return Handle.takeError();
}

static void findLocalExecutorHelper() {}
std::string findLocalExecutor(const char *HostArgv0) {
  // This just needs to be some static symbol in the binary; C++ doesn't
  // allow taking the address of ::main however.
  uintptr_t UIntPtr = reinterpret_cast<uintptr_t>(&findLocalExecutorHelper);
  void *VoidPtr = reinterpret_cast<void *>(UIntPtr);
  SmallString<256> FullName(sys::fs::getMainExecutable(HostArgv0, VoidPtr));
  sys::path::remove_filename(FullName);
  sys::path::append(FullName, "llvm-jitlink-executor");
  return FullName.str().str();
}

#ifndef LLVM_ON_UNIX

Expected<std::pair<std::unique_ptr<shared::FDRawByteChannel>, uint32_t>>
launchLocalExecutor(StringRef ExecutablePath) {
  return make_error<StringError>(
      "Remote JITing not yet supported on non-unix platforms",
      inconvertibleErrorCode());
}

Expected<std::unique_ptr<shared::FDRawByteChannel>>
connectTCPSocket(StringRef NetworkAddress) {
  return make_error<StringError>(
      "Remote JITing not yet supported on non-unix platforms",
      inconvertibleErrorCode());
}

#else

Expected<std::pair<std::unique_ptr<shared::FDRawByteChannel>, uint32_t>>
launchLocalExecutor(StringRef ExecutablePath) {
  constexpr int ReadEnd = 0;
  constexpr int WriteEnd = 1;

  if (!sys::fs::can_execute(ExecutablePath))
    return make_error<StringError>(
        formatv("Specified executor invalid: {0}", ExecutablePath),
        inconvertibleErrorCode());

  // Pipe FDs.
  int ToExecutor[2];
  int FromExecutor[2];

  // Create pipes to/from the executor..
  if (pipe(ToExecutor) != 0 || pipe(FromExecutor) != 0)
    return make_error<StringError>("Unable to create pipe for executor",
                                   inconvertibleErrorCode());

  pid_t ProcessID = fork();
  if (ProcessID == 0) {
    // In the child...

    // Close the parent ends of the pipes
    close(ToExecutor[WriteEnd]);
    close(FromExecutor[ReadEnd]);

    // Execute the child process.
    std::unique_ptr<char[]> ExecPath, FDSpecifier;
    {
      ExecPath = std::make_unique<char[]>(ExecutablePath.size() + 1);
      strcpy(ExecPath.get(), ExecutablePath.data());

      std::string FDSpecifierStr("filedescs=");
      FDSpecifierStr += utostr(ToExecutor[ReadEnd]);
      FDSpecifierStr += ',';
      FDSpecifierStr += utostr(FromExecutor[WriteEnd]);
      FDSpecifier = std::make_unique<char[]>(FDSpecifierStr.size() + 1);
      strcpy(FDSpecifier.get(), FDSpecifierStr.c_str());
    }

    char *const Args[] = {ExecPath.get(), FDSpecifier.get(), nullptr};
    int RC = execvp(ExecPath.get(), Args);
    if (RC != 0)
      return make_error<StringError>(
          "Unable to launch out-of-process executor '" + ExecutablePath + "'\n",
          inconvertibleErrorCode());

    llvm_unreachable("Fork won't return in success case");
  }
  // else we're the parent...

  // Close the child ends of the pipes
  close(ToExecutor[ReadEnd]);
  close(FromExecutor[WriteEnd]);

  return std::make_pair(std::make_unique<shared::FDRawByteChannel>(FromExecutor[ReadEnd], ToExecutor[WriteEnd]),
    static_cast<uint32_t>(ProcessID));
}

static Expected<int> connectTCPSocketImpl(std::string Host,
                                          std::string PortStr) {
  addrinfo *AI;
  addrinfo Hints{};
  Hints.ai_family = AF_INET;
  Hints.ai_socktype = SOCK_STREAM;
  Hints.ai_flags = AI_NUMERICSERV;

  if (int EC = getaddrinfo(Host.c_str(), PortStr.c_str(), &Hints, &AI))
    return make_error<StringError>(
        formatv("address resolution failed ({0})", gai_strerror(EC)),
        inconvertibleErrorCode());

  // Cycle through the returned addrinfo structures and connect to the first
  // reachable endpoint.
  int SockFD;
  addrinfo *Server;
  for (Server = AI; Server != nullptr; Server = Server->ai_next) {
    // If socket fails, maybe it's because the address family is not supported.
    // Skip to the next addrinfo structure.
    if ((SockFD = socket(AI->ai_family, AI->ai_socktype, AI->ai_protocol)) < 0)
      continue;

    // If connect works, we exit the loop with a working socket.
    if (connect(SockFD, Server->ai_addr, Server->ai_addrlen) == 0)
      break;

    close(SockFD);
  }
  freeaddrinfo(AI);

  // Did we reach the end of the loop without connecting to a valid endpoint?
  if (Server == nullptr)
    return make_error<StringError>("invalid hostname",
                                   inconvertibleErrorCode());

  return SockFD;
}

Expected<std::unique_ptr<shared::FDRawByteChannel>>
connectTCPSocket(StringRef NetworkAddress) {
  auto CreateErr = [NetworkAddress](StringRef Details) {
    return make_error<StringError>(
        formatv("Failed to connect TCP socket '{0}': {1}", NetworkAddress,
                Details),
        inconvertibleErrorCode());
  };

  StringRef Host, PortStr;
  std::tie(Host, PortStr) = NetworkAddress.split(':');
  if (Host.empty())
    return CreateErr("host name cannot be empty");
  if (PortStr.empty())
    return CreateErr("port cannot be empty");
  int Port = 0;
  if (PortStr.getAsInteger(10, Port))
    return CreateErr("port number is not a valid integer");

  Expected<int> SockFD = connectTCPSocketImpl(Host.str(), PortStr.str());
  if (!SockFD)
    return CreateErr(toString(SockFD.takeError()));

  return std::make_unique<shared::FDRawByteChannel>(*SockFD, *SockFD);
}

} // namespace orc
} // namespace llvm

#endif
