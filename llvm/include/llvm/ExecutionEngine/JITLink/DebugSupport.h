//===------------ DebugSupport.h - JITLink debug utils ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Create companion objects for consumption by a debugger.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_JITLINK_DEBUGSUPPORT_H
#define LLVM_EXECUTIONENGINE_JITLINK_DEBUGSUPPORT_H

#include "llvm/ADT/Triple.h"
#include "llvm/ExecutionEngine/JITLink/JITLink.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Memory.h"
#include "llvm/Support/MemoryBuffer.h"

#include <functional>
#include <memory>

namespace llvm {
namespace jitlink {

/// Abstract interface for debug objects in the DebugObjectManagerPlugin.
///
/// The plugin requests a debug object from JITLinkContext when JITLink starts
/// processing the corresponding LinkGraph. It provides access to the pass
/// configuration of the LinkGraph and calls the finalization function, once
/// the resulting link artifact was emitted.
///
class DebugObject {
public:
  using FinalizeContinuation = std::function<void(Expected<sys::MemoryBlock>)>;

  virtual void modifyPassConfig(const Triple &TT,
                                PassConfiguration &PassConfig) = 0;
  virtual void finalizeAsync(FinalizeContinuation OnFinalize) = 0;
  virtual ~DebugObject() {}
};

/// Creates a debug object based on the input object file from
/// ObjectLinkingLayerJITLinkContext.
///
/// It replicates the approach used in RuntimeDyld: Patching executable and data
/// section headers in the given object buffer with load-addresses of their
/// corresponding LinkGraph segments in target memory.
///
Expected<std::unique_ptr<DebugObject>>
createDebugObjectFromBuffer(const Triple &TT, JITLinkContext &Ctx,
                            std::unique_ptr<WritableMemoryBuffer> Buffer);

} // namespace jitlink
} // namespace llvm

#endif // LLVM_EXECUTIONENGINE_JITLINK_DEBUGSUPPORT_H
