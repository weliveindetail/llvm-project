//===-- RemoteJITUtils.cpp - Utilities for remote-JITing --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RemoteJITUtils.h"

#include "llvm/ADT/Triple.h"
#include "llvm/ExecutionEngine/Orc/SymbolStringPool.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"

using namespace llvm;
using namespace orc;

Expected<JITLinkExecutor> JITLinkExecutor::Create(std::string ExecutablePath) {
  if (!sys::fs::can_execute(ExecutablePath))
    return make_error<StringError>("Specified executor invalid: " + ExecutablePath,
                                  inconvertibleErrorCode());
  return JITLinkExecutor(std::move(ExecutablePath));
}

Expected<JITLinkExecutor> JITLinkExecutor::Find(const char *JITArgv0) {
  std::string ExecutablePath = defaultPath(JITArgv0, "llvm-jitlink-executor");
  if (!sys::fs::can_execute(ExecutablePath))
    return make_error<StringError>("Unable to find usable executor: " + ExecutablePath,
                                  inconvertibleErrorCode());
  return JITLinkExecutor(std::move(ExecutablePath));
}

LLVM_ATTRIBUTE_USED static void localFunction() {}

std::string JITLinkExecutor::defaultPath(const char *JITArgv0, StringRef ExecutorName) {
  SmallString<256> FullName(sys::fs::getMainExecutable(
      JITArgv0, reinterpret_cast<void *>(&localFunction)));
  sys::path::remove_filename(FullName);
  if (FullName.back() != '/')
    FullName += '/';
  FullName += ExecutorName;
  return FullName.str().str();
}

#ifndef LLVM_ON_UNIX

// FIXME: Add support for Windows.
Expected<std::unique_ptr<JITLinkExecutor::RPCChannel>> JITLinkExecutor::launch() {
  return make_error<StringError>("Remote JITing not yet supported on non-unix platforms",
                                 inconvertibleErrorCode());
}

#else

Expected<std::unique_ptr<JITLinkExecutor::RPCChannel>> JITLinkExecutor::launch() {
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
          "Unable to launch out-of-process executor \"" + ExecutablePath + "\"\n",
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

RemoteTargetProcessControl::RemoteTargetProcessControl(
    std::shared_ptr<orc::SymbolStringPool> SSP,
    std::unique_ptr<RPCChannel> Channel,
    std::unique_ptr<RPCEndpoint> Endpoint,
    ErrorReporter ReportError)
    : BaseT(std::move(SSP), *Endpoint, std::move(ReportError)),
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
Expected<std::unique_ptr<RemoteTargetProcessControl>>
RemoteTargetProcessControl::Create(orc::ExecutionSession &ES,
                                      std::unique_ptr<RPCChannel> Channel) {
  auto Endpoint = std::make_unique<RPCEndpoint>(*Channel, true);
  std::unique_ptr<RemoteTargetProcessControl> TPC(
      new RemoteTargetProcessControl(
          ES.getSymbolStringPool(), std::move(Channel), std::move(Endpoint),
          [&ES](Error Err) { ES.reportError(std::move(Err)); }));

  if (auto Err = TPC->initializeORCRPCTPCBase())
    return joinErrors(std::move(Err), TPC->disconnect());

  TPC->initializeMemoryManagement();

  orc::shared::registerStringError<RPCChannel>();
  return std::move(TPC);
}

void RemoteTargetProcessControl::initializeMemoryManagement() {
  OwnedMemAccess = std::make_unique<MemoryAccess>(*this);
  OwnedMemMgr = std::make_unique<MemoryManager>(*this);

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

#endif
