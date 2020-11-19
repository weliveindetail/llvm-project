//===-- MachOPlatform.h - Utilities for executing MachO in Orc --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Utilities for executing JIT'd MachO in Orc.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_EXECUTIONENGINE_ORC_MACHOPLATFORM_H
#define LLVM_EXECUTIONENGINE_ORC_MACHOPLATFORM_H

#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ExecutionUtils.h"
#include "llvm/ExecutionEngine/Orc/ObjectLinkingLayer.h"
#include "llvm/ExecutionEngine/Orc/Shared/WrapperFunctionUtils.h"
#include "llvm/ExecutionEngine/Orc/WrapperFunctionManager.h"
#include "llvm/ExecutionEngine/Orc/Shared/MachOPlatformTypes.h"

#include <future>
#include <thread>
#include <vector>

namespace llvm {
namespace orc {

/// Enable registration of JIT'd ObjC classes and selectors.
Error enableObjCRegistration(const char *PathToLibObjC);
bool objCRegistrationEnabled();

/// Mediates between MachO initialization and ExecutionSession state.
class MachOPlatform : public Platform {
public:

  using RuntimeSupportWrapperPlatformMethod =
    shared::WrapperFunctionResult (MachOPlatform::*)(ArrayRef<uint8_t>);

  using RuntimeSupportWrapperFunctionsMap =
      DenseMap<SymbolStringPtr, WrapperFunctionManager::WrapperFunction>;

  using InitializerSequence = shared::MachOPlatformInitializerSequence;
  using DeinitializerSequence = shared::MachOPlatformDeinitializerSequence;

  static Expected<std::unique_ptr<MachOPlatform>>
  Create(ExecutionSession &ES, ObjectLinkingLayer &ObjLinkingLayer,
         Triple TT);

  ExecutionSession &getExecutionSession() const { return ES; }

  ObjectLinkingLayer &getObjectLinkingLayer() const { return ObjLinkingLayer; }

  const Triple &getTargetTriple() const { return TT; }

  Error setupJITDylib(JITDylib &JD) override;
  Error notifyAdding(ResourceTracker &RT,
                     const MaterializationUnit &MU) override;

  /// Return the initializer sequence required to initialize the given JITDylib
  /// (and any uninitialized dependencies).
  Expected<InitializerSequence> getInitializerSequence(JITDylib &JD);

  /// Return the deinitializer sequence required to deinitialize the given
  /// JITDylib.
  Expected<DeinitializerSequence> getDeinitializerSequence(JITDylib &JD);

  /// Return the result of a dlsym style lookup based on the given dso_handle
  /// and symbol name.
  Expected<JITTargetAddress> dlsymLookup(JITTargetAddress DSOHandle,
                                         StringRef Symbol);

  /// Add MachO runtime support functions for an in-process copy of the runtime.
  ///
  /// May return an error if the runtime function names clash with any existing
  /// definitions.
  Error addInProcessRuntimeSupport(JITDylib &JD);

  /// Add MachO runtime support functions for an out-of-process copy of the
  /// runtime.
  ///
  /// May return an error if the runtime function names clash with any existing
  /// definitions.
  Error addRemoteRuntimeSupport(JITDylib &JD, WrapperFunctionManager &WFM);

  /// Wrapper for jit_dlopen suitable for use with runWrapper dispatch.
  shared::WrapperFunctionResult
  rt_getInitializerSequenceWrapper(ArrayRef<uint8_t> ArgBuffer);

  /// Wrapper for jit_dlsym suitable for use with runWrapper dispatch.
  shared::WrapperFunctionResult
  rt_dlsymLookupWrapper(ArrayRef<uint8_t> ArgBuffer);

  /// Returns a WrapperFunctionManager::WrapperFunction wrapping the given
  /// method (invoking it on 'this').
  WrapperFunctionManager::WrapperFunction
  runtimeSupportMethod(RuntimeSupportWrapperPlatformMethod M) {
    return [this, M](ArrayRef<uint8_t> ArgBuffer) {
      return (this->*M)(ArgBuffer);
    };
  }

  /// Run mod-init functions in-process.
  /// WARNING: This method is deprecated and will be removed in the near
  /// future.
  void runModInits(shared::MachOJITDylibInitializers &MOIs) const;

  /// Register obj-c selectors in-process.
  /// WARNING: This method is deprecated and will be removed in the near
  /// future.
  void registerObjCSelectors(shared::MachOJITDylibInitializers &MOIs) const;

  /// Register obj-c classes in-process.
  /// WARNING: This method is deprecated and will be removed in the near
  /// future.
  Error registerObjCClasses(shared::MachOJITDylibInitializers &MOIs) const;

private:
  // This ObjectLinkingLayer plugin scans JITLink graphs for __mod_init_func,
  // __objc_classlist and __sel_ref sections and records their extents so that
  // they can be run in the target process.
  class InitScraperPlugin : public ObjectLinkingLayer::Plugin {
  public:
    InitScraperPlugin(MachOPlatform &MP) : MP(MP) {}

    void modifyPassConfig(MaterializationResponsibility &MR, const Triple &TT,
                          jitlink::PassConfiguration &Config) override;

    LocalDependenciesMap getSyntheticSymbolLocalDependencies(
        MaterializationResponsibility &MR) override;

    // FIXME: We should be tentatively tracking scraped sections and discarding
    // if the MR fails.
    Error notifyFailed(MaterializationResponsibility &MR) override {
      return Error::success();
    }

    Error notifyRemovingResources(ResourceKey K) override {
      return Error::success();
    }

    void notifyTransferringResources(ResourceKey DstKey,
                                     ResourceKey SrcKey) override {}

  private:
    using InitSymbolDepMap =
        DenseMap<MaterializationResponsibility *, JITLinkSymbolVector>;

    void preserveInitSectionIfPresent(JITLinkSymbolVector &Syms,
                                      jitlink::LinkGraph &G,
                                      StringRef SectionName);

    Error processObjCImageInfo(jitlink::LinkGraph &G,
                               MaterializationResponsibility &MR);

    std::mutex InitScraperMutex;
    MachOPlatform &MP;
    DenseMap<JITDylib *, std::pair<uint32_t, uint32_t>> ObjCImageInfos;
    InitSymbolDepMap InitSymbolDeps;
  };

  static bool supportedTarget(const Triple &TT);

  MachOPlatform(ExecutionSession &ES, ObjectLinkingLayer &ObjLinkingLayer,
                Triple TT);

  Error registerInitInfo(
      JITDylib &JD, JITTargetAddress ObjCImageInfoAddr,
      shared::MachOJITDylibInitializers::SectionExtent ModInits,
      shared::MachOJITDylibInitializers::SectionExtent ObjCSelRefs,
      shared::MachOJITDylibInitializers::SectionExtent ObjCClassList);

  ExecutionSession &ES;
  ObjectLinkingLayer &ObjLinkingLayer;
  Triple TT;
  SymbolStringPtr MachOHeaderStartSymbol;

  DenseMap<JITDylib *, SymbolLookupSet> RegisteredInitSymbols;

  // InitSeqs gets its own mutex to avoid locking the whole session when
  // aggregating data from the jitlink.
  std::mutex InitSeqsMutex;
  DenseMap<JITDylib *, shared::MachOJITDylibInitializers> InitSeqs;
  DenseMap<JITTargetAddress, JITDylib *> HeaderAddrToJITDylib;
};

} // end namespace orc
} // end namespace llvm

#endif // LLVM_EXECUTIONENGINE_ORC_MACHOPLATFORM_H
