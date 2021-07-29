//===-- RemoteJITUtils.cpp - Utilities for remote-JITing --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RemoteJITUtils.h"

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/Triple.h"
#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/Layer.h"
#include "llvm/ExecutionEngine/Orc/DebugObjectManagerPlugin.h"
#include "llvm/ExecutionEngine/Orc/EPCDebugObjectRegistrar.h"
#include "llvm/ExecutionEngine/Orc/EPCDynamicLibrarySearchGenerator.h"
#include "llvm/ExecutionEngine/Orc/OrcRPCExecutorProcessControl.h"
#include "llvm/ExecutionEngine/Orc/Shared/FDRawByteChannel.h"
#include "llvm/ExecutionEngine/Orc/Shared/RPCUtils.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"

#ifdef LLVM_ON_UNIX
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#endif // LLVM_ON_UNIX

#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#else
#include <io.h>
#endif

namespace llvm {
namespace orc {

using RPCChannel = shared::FDRawByteChannel;

class RemoteExecutorProcessControl
    : public OrcRPCExecutorProcessControlBase<
          shared::MultiThreadedRPCEndpoint<RPCChannel>> {
public:
  using RPCChannel = RPCChannel;
  using RPCEndpoint = shared::MultiThreadedRPCEndpoint<RPCChannel>;

private:
  using ThisT = RemoteExecutorProcessControl;
  using BaseT = OrcRPCExecutorProcessControlBase<RPCEndpoint>;
  using MemoryAccess = OrcRPCEPCMemoryAccess<ThisT>;
  using MemoryManager = OrcRPCEPCJITLinkMemoryManager<ThisT>;

public:
  using BaseT::initializeORCRPCEPCBase;

  static Expected<std::unique_ptr<RemoteExecutorProcessControl>>
  Create(std::unique_ptr<RPCChannel> Channel, BaseT::ErrorReporter ReportError);

  RemoteExecutorProcessControl(std::unique_ptr<RPCChannel> Channel,
                               std::unique_ptr<RPCEndpoint> Endpoint,
                               BaseT::ErrorReporter ReportError);

  void initializeMemoryManagement();
  Error disconnect() override;

private:
  std::unique_ptr<RPCChannel> Channel;
  std::unique_ptr<RPCEndpoint> Endpoint;
  std::unique_ptr<MemoryAccess> OwnedMemAccess;
  std::unique_ptr<MemoryManager> OwnedMemMgr;
  std::atomic<bool> Finished{false};
  std::thread ListenerThread;
};

Expected<std::unique_ptr<RemoteExecutorProcessControl>>
RemoteExecutorProcessControl::Create(std::unique_ptr<RPCChannel> Channel,
                                     BaseT::ErrorReporter ReportError) {
  auto Endpoint = std::make_unique<RemoteExecutorProcessControl::RPCEndpoint>(
      *Channel, true);

  auto EPC = std::make_unique<RemoteExecutorProcessControl>(
      std::move(Channel), std::move(Endpoint), std::move(ReportError));

  if (auto Err = EPC->initializeORCRPCEPCBase())
    return joinErrors(std::move(Err), EPC->disconnect());

  EPC->initializeMemoryManagement();

  shared::registerStringError<RPCChannel>();
  return EPC;
}

RemoteExecutorProcessControl::RemoteExecutorProcessControl(
    std::unique_ptr<RPCChannel> Channel, std::unique_ptr<RPCEndpoint> Endpoint,
    BaseT::ErrorReporter ReportError)
    : BaseT(std::make_shared<SymbolStringPool>(), *Endpoint,
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

void RemoteExecutorProcessControl::initializeMemoryManagement() {
  OwnedMemAccess = std::make_unique<MemoryAccess>(*this);
  OwnedMemMgr = std::make_unique<MemoryManager>(*this);

  // Base class needs non-owning access.
  MemAccess = OwnedMemAccess.get();
  MemMgr = OwnedMemMgr.get();
}

Error RemoteExecutorProcessControl::disconnect() {
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

static std::string defaultExecutorPath(const char *HostArgv0, StringRef Name) {
  // This just needs to be some symbol in the binary; C++ doesn't
  // allow taking the address of ::main however.
  void *P = (void *)(intptr_t)defaultExecutorPath;
  SmallString<256> FullPath(sys::fs::getMainExecutable(HostArgv0, P));
  sys::path::remove_filename(FullPath);
  sys::path::append(FullPath, Name);
  return FullPath.str().str();
}

Expected<std::string> getLocalExecutor(std::string Hint,
                                       const char *HostArgv0) {
  if (Hint.empty())
    Hint = defaultExecutorPath(HostArgv0, "llvm-jitlink-executor");
  if (!sys::fs::can_execute(Hint))
    return make_error<StringError>("Invalid executor: " + StringRef(Hint),
                                   inconvertibleErrorCode());
  return Hint;
}

#ifndef LLVM_ON_UNIX

// FIXME: Add support for Windows.
static Expected<std::unique_ptr<RPCChannel>>
launchSubprocessImpl(StringRef ExecutablePath, int &ProcessID) {
  return make_error<StringError>(
      "Remote JITing not yet supported on non-unix platforms",
      inconvertibleErrorCode());
}

// FIXME: Add support for Windows.
static Expected<std::unique_ptr<RPCChannel>>
connectTCPSocketImpl(std::string Host, std::string PortStr) {
  return make_error<StringError>(
      "Remote JITing not yet supported on non-unix platforms",
      inconvertibleErrorCode());
}

#else

static Expected<std::unique_ptr<RPCChannel>>
launchSubprocessImpl(StringRef ExecutablePath, int &ProcessID) {
  constexpr int ReadEnd = 0;
  constexpr int WriteEnd = 1;

  // Pipe FDs.
  int ToExecutor[2];
  int FromExecutor[2];

  // Create pipes to/from the executor..
  if (pipe(ToExecutor) != 0 || pipe(FromExecutor) != 0)
    return make_error<StringError>("Unable to create pipe for executor",
                                   inconvertibleErrorCode());

  ProcessID = fork();
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
          "Unable to launch out-of-process executor '" + ExecutablePath,
          inconvertibleErrorCode());

    llvm_unreachable("Fork won't return in success case");
  }
  // else we're the parent...

  // Close the child ends of the pipes
  close(ToExecutor[ReadEnd]);
  close(FromExecutor[WriteEnd]);

  return std::make_unique<RPCChannel>(FromExecutor[ReadEnd],
                                      ToExecutor[WriteEnd]);
}

static Expected<std::unique_ptr<RPCChannel>>
connectTCPSocketImpl(std::string Host, std::string PortStr) {
  addrinfo *AI;
  addrinfo Hints{};
  Hints.ai_family = AF_INET;
  Hints.ai_socktype = SOCK_STREAM;
  Hints.ai_flags = AI_NUMERICSERV;

  if (int EC = getaddrinfo(Host.c_str(), PortStr.c_str(), &Hints, &AI))
    return make_error<StringError>(
        formatv("address resolution failed ({0})", gai_strerror(EC)),
        inconvertibleErrorCode());

  // Iterate through the returned addrinfo structures and connect to the first
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

  return std::make_unique<RPCChannel>(SockFD, SockFD);
}

#endif // LLVM_ON_UNIX

Expected<std::unique_ptr<ExecutorProcessControl>>
launchSubprocess(StringRef ExecutablePath,
                 unique_function<void(Error)> ErrorReporter, int &ProcessID) {
  if (auto Ch = launchSubprocessImpl(ExecutablePath, ProcessID))
    return RemoteExecutorProcessControl::Create(std::move(*Ch),
                                                std::move(ErrorReporter));
  else
    return Ch.takeError();
}

Expected<std::unique_ptr<ExecutorProcessControl>>
connectTCPSocket(StringRef NetworkAddress,
                 unique_function<void(Error)> ErrorReporter) {
  auto FormatError = [NetworkAddress](StringRef Details) {
    const char *Fmt = "Failed to connect TCP socket '{0}': {1}";
    return make_error<StringError>(formatv(Fmt, NetworkAddress, Details),
                                   inconvertibleErrorCode());
  };

  StringRef Host, PortStr;
  std::tie(Host, PortStr) = NetworkAddress.split(':');
  if (Host.empty())
    return FormatError("host name cannot be empty");
  if (PortStr.empty())
    return FormatError("port cannot be empty");
  int Port = 0;
  if (PortStr.getAsInteger(10, Port))
    return FormatError("port number is not a valid integer");

  if (auto Ch = connectTCPSocketImpl(Host.str(), PortStr.str()))
    return RemoteExecutorProcessControl::Create(std::move(*Ch),
                                                std::move(ErrorReporter));
  else
    return FormatError(toString(Ch.takeError()));
}

} // namespace orc
} // namespace llvm
