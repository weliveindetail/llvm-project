//===---- DebugObjectManagerPlugin.h - JITLink debug objects ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// ObjectLinkingLayer plugin for emitting debug objects.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_DEBUGOBJECTMANAGERPLUGIN_H
#define LLVM_EXECUTIONENGINE_ORC_DEBUGOBJECTMANAGERPLUGIN_H

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/Triple.h"
#include "llvm/ExecutionEngine/JITLink/DebugSupport.h"
#include "llvm/ExecutionEngine/JITLink/JITLink.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"
#include "llvm/ExecutionEngine/Orc/TPCDebugObjectRegistrar.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Memory.h"

#include <functional>
#include <memory>
#include <mutex>

namespace llvm {
namespace orc {

/// Requests and manages DebugObjects for JITLink artifacts.
///
/// For each processed MaterializationResponsibility a DebugObject is requested
/// from JITLinkContext. DebugObjects are pending as long as their corresponding
/// MaterializationResponsibility did not finish loading.
///
/// There can only be one pending DebugObject per MaterializationResponsibility.
/// Pending DebugObjects for failed MaterializationResponsibility are discarded.
///
/// Once loading finished, DebugObjects are finalized and their target memory
/// is reported to the provided DebugObjectRegistrar. Ownership of DebugObjects
/// remains with the plugin.
///
class DebugObjectManagerPlugin : public ObjectLinkingLayer::Plugin {
public:
  DebugObjectManagerPlugin(ExecutionSession &ES,
                           std::unique_ptr<DebugObjectRegistrar> Target)
      : ES(ES), Target(std::move(Target)) {}

  void notifyMaterializing(MaterializationResponsibility &MR,
                           jitlink::LinkGraph &G,
                           jitlink::JITLinkContext &Ctx) override;

  void notifyLoaded(MaterializationResponsibility &MR) override;
  Error notifyFailed(MaterializationResponsibility &MR) override;
  Error notifyRemovingResources(ResourceKey K) override;

  void notifyTransferringResources(ResourceKey DstKey,
                                   ResourceKey SrcKey) override;

  void modifyPassConfig(MaterializationResponsibility &MR, const Triple &TT,
                        jitlink::PassConfiguration &PassConfig) override;

private:
  ExecutionSession &ES;

  using DebugObjectPtr = std::unique_ptr<jitlink::DebugObject>;
  DenseMap<ResourceKey, std::vector<DebugObjectPtr>> RegisteredObjs;
  DenseMap<ResourceKey, DebugObjectPtr> PendingObjs;

  std::mutex RegisteredObjsLock;
  std::mutex PendingObjsLock;

  std::unique_ptr<DebugObjectRegistrar> Target;
};

} // namespace orc
} // namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_DEBUGOBJECTMANAGERPLUGIN_H
