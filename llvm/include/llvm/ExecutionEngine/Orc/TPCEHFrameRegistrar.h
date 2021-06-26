//===-- TPCEHFrameRegistrar.h - TPC based eh-frame registration -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TargetProcessControl based eh-frame registration.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_TPCEHFRAMEREGISTRAR_H
#define LLVM_EXECUTIONENGINE_ORC_TPCEHFRAMEREGISTRAR_H

#include "llvm/ExecutionEngine/JITLink/EHFrameSupport.h"

namespace llvm {
namespace orc {

class ExecutionSession;

/// Register/Deregisters EH frames in a remote process via a
/// TargetProcessControl instance.
class TPCEHFrameRegistrar : public jitlink::EHFrameRegistrar {
public:
  /// Create from a TargetProcessControl instance alone. This will use
  /// the TPC's lookupSymbols method to find the registration/deregistration
  /// funciton addresses by name.
  static Expected<std::unique_ptr<TPCEHFrameRegistrar>>
  Create(ExecutionSession &ES);

  /// Create a TPCEHFrameRegistrar with the given TargetProcessControl
  /// object and registration/deregistration function addresses.
  TPCEHFrameRegistrar(ExecutionSession &ES,
                      JITTargetAddress RegisterEHFrameWrapperFnAddr,
                      JITTargetAddress DeregisterEHFRameWrapperFnAddr)
      : ES(ES), RegisterEHFrameWrapperFnAddr(RegisterEHFrameWrapperFnAddr),
        DeregisterEHFrameWrapperFnAddr(DeregisterEHFRameWrapperFnAddr) {}

  Error registerEHFrames(JITTargetAddress EHFrameSectionAddr,
                         size_t EHFrameSectionSize) override;
  Error deregisterEHFrames(JITTargetAddress EHFrameSectionAddr,
                           size_t EHFrameSectionSize) override;

private:
  ExecutionSession &ES;
  JITTargetAddress RegisterEHFrameWrapperFnAddr;
  JITTargetAddress DeregisterEHFrameWrapperFnAddr;
};

} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_TPCEHFRAMEREGISTRAR_H
