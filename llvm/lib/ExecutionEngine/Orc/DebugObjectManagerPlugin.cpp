//===---- DebugObjectManagerPlugin.h - JITLink debug objects ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ExecutionEngine/Orc/DebugObjectManagerPlugin.h"

#include "llvm/Support/Memory.h"

#define DEBUG_TYPE "orc"

using namespace llvm::jitlink;

namespace llvm {
namespace orc {

static ResourceKey getResourceKey(MaterializationResponsibility &MR) {
  ResourceKey Key;
  if (auto Err = MR.withResourceKeyDo([&](ResourceKey K) { Key = K; })) {
    MR.getExecutionSession().reportError(std::move(Err));
    return ResourceKey{};
  }
  assert(Key && "Invalid key");
  return Key;
}

void DebugObjectManagerPlugin::notifyMaterializing(
    MaterializationResponsibility &MR, LinkGraph &G, JITLinkContext &Ctx) {
  std::lock_guard<std::mutex> Lock(PendingObjsLock);

  // We should never have more than one pending debug object.
  ResourceKey Key = getResourceKey(MR);
  auto It = PendingObjs.find(Key);
  if (It != PendingObjs.end()) {
    ES.reportError(make_error<StringError>(
        formatv("Materializing new LinkGraph '{0}' for pending resource: {1}",
                G.getName(), Key),
        inconvertibleErrorCode()));
    return;
  }

  Expected<std::unique_ptr<DebugObject>> DebugObj = Ctx.createDebugObject(G);
  if (!DebugObj) {
    ES.reportError(DebugObj.takeError());
    return;
  }

  // Not all link artifacts allow debugging.
  if (*DebugObj)
    PendingObjs[Key] = std::move(*DebugObj);
}

void DebugObjectManagerPlugin::modifyPassConfig(
    MaterializationResponsibility &MR, const Triple &TT,
    PassConfiguration &PassConfig) {
  // Not all link artifacts have associated debug objects.
  DebugObject *DebugObj = nullptr;
  {
    std::lock_guard<std::mutex> Lock(PendingObjsLock);
    auto It = PendingObjs.find(getResourceKey(MR));
    if (It == PendingObjs.end())
      return;
    DebugObj = It->second.get();
  }
  DebugObj->modifyPassConfig(TT, PassConfig);
}

void DebugObjectManagerPlugin::notifyLoaded(MaterializationResponsibility &MR) {
  ResourceKey Key = getResourceKey(MR);
  DebugObject *UnownedDebugObj = nullptr;
  {
    std::lock_guard<std::mutex> Lock(PendingObjsLock);
    auto It = PendingObjs.find(Key);
    if (It != PendingObjs.end()) {
      UnownedDebugObj = It->second.release();
      PendingObjs.erase(It);
    }
  }

  // We released ownership of DebugObj, so we can easily capture the raw pointer
  // in the continuation function, which re-owns it immediately.
  if (UnownedDebugObj)
    UnownedDebugObj->finalizeAsync(
        [this, Key, UnownedDebugObj](Expected<sys::MemoryBlock> TargetMem) {
          std::unique_ptr<DebugObject> ReownedDebugObj(UnownedDebugObj);
          if (!TargetMem) {
            ES.reportError(TargetMem.takeError());
            return;
          }
          if (Error Err = Target->registerDebugObject(*TargetMem)) {
            ES.reportError(std::move(Err));
            return;
          }

          std::lock_guard<std::mutex> Lock(RegisteredObjsLock);
          RegisteredObjs[Key].push_back(std::move(ReownedDebugObj));
        });
}

Error DebugObjectManagerPlugin::notifyFailed(
    MaterializationResponsibility &MR) {
  std::lock_guard<std::mutex> Lock(PendingObjsLock);
  PendingObjs.erase(getResourceKey(MR));
  return Error::success();
}

void DebugObjectManagerPlugin::notifyTransferringResources(ResourceKey DstKey,
                                                           ResourceKey SrcKey) {
  {
    std::lock_guard<std::mutex> Lock(RegisteredObjsLock);
    auto SrcIt = RegisteredObjs.find(SrcKey);
    if (SrcIt != RegisteredObjs.end()) {
      for (std::unique_ptr<DebugObject> &Alloc : SrcIt->second)
        RegisteredObjs[DstKey].push_back(std::move(Alloc));
      RegisteredObjs.erase(SrcIt);
    }
  }
  {
    std::lock_guard<std::mutex> Lock(PendingObjsLock);
    auto SrcIt = PendingObjs.find(SrcKey);
    if (SrcIt != PendingObjs.end()) {
      if (PendingObjs.count(DstKey)) {
        ES.reportError(make_error<StringError>(
            formatv(
                "Destination '{0}' for transferring pending debug object has "
                "a pending resource already: {1}",
                DstKey, SrcKey),
            inconvertibleErrorCode()));
      } else {
        PendingObjs[DstKey] = std::move(SrcIt->second);
        PendingObjs.erase(SrcIt);
      }
    }
  }
}

Error DebugObjectManagerPlugin::notifyRemovingResources(ResourceKey K) {
  {
    std::lock_guard<std::mutex> Lock(RegisteredObjsLock);
    RegisteredObjs.erase(K);
    // TODO: Implement unregister notifications.
  }
  std::lock_guard<std::mutex> Lock(PendingObjsLock);
  PendingObjs.erase(K);

  return Error::success();
}

} // namespace orc
} // namespace llvm
