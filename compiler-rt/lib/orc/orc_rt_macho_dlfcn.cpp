//===-- orc_rt_macho_dlfcn.cpp ----------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of the ORC runtime support library.
//
//===----------------------------------------------------------------------===//

#include "orc_rt_common.h"
#include "orc_rt_cxa.h"
#include "orc_rt_macho_dlfcn.h"

#include "llvm/ExecutionEngine/Orc/Shared/MachOPlatformTypes.h"

#include <pthread.h>
#include <memory>
#include <unordered_map>

using namespace llvm;
using namespace llvm::orc;
using namespace llvm::orc::shared;

using namespace orc_rt;

struct objc_class;
struct objc_image_info;
struct objc_object;
struct objc_selector;

using Class = objc_class *;
using id = objc_object *;
using SEL = objc_selector *;

extern "C" id objc_msgSend(id, SEL, ...) __attribute__((weak_import));
extern "C" Class
objc_readClassPair(Class, const objc_image_info *) __attribute__((weak_import));

extern "C" SEL sel_registerName(const char *) __attribute__((weak_import));

ORC_RT_INTERFACE
Expected<MachOPlatformInitializerSequence>
__orc_rt_macho_get_initializers(const char *path);

ORC_RT_INTERFACE
Expected<JITTargetAddress>
__orc_rt_macho_symbol_lookup(void *dso_handle, const char *sym);

namespace {

struct PerJITDylibRuntimeState {
  void *Header = nullptr;
  size_t RefCount = 0;
  bool AllowReinitialization = false;
};

struct JITDylibRuntimeState {
  pthread_mutex_t JDRuntimeStateMutex = PTHREAD_MUTEX_INITIALIZER;
  std::unordered_map<std::string, PerJITDylibRuntimeState> PerJDState;
};

std::string MachODLFcnError;

} // end anonymous namespace

static JITDylibRuntimeState &getJITDylibRuntimeState() {
  static std::unique_ptr<JITDylibRuntimeState> JDRuntimeState =
    std::make_unique<JITDylibRuntimeState>();
  return *JDRuntimeState;
}

static void registerObjCSelectors(const MachOJITDylibInitializers &MOJDIs) {
  assert(sel_registerName && "sel_registerName not available");

  for (const auto &ObjCSelRefs : MOJDIs.getObjCSelRefsSections()) {
    for (uint64_t I = 0; I != ObjCSelRefs.NumPtrs; ++I) {
      auto SelEntryAddr = ObjCSelRefs.Address + (I * sizeof(uintptr_t));
      const char *SelName =
          *jitTargetAddressToPointer<const char **>(SelEntryAddr);
      auto Sel = sel_registerName(SelName);
      *jitTargetAddressToPointer<SEL *>(SelEntryAddr) = Sel;
    }
  }
}

static Error registerObjCClasses(const MachOJITDylibInitializers &MOJDIs) {
  assert(objc_msgSend && "objc_msgSend not available");
  assert(objc_readClassPair && "objc_readClassPair not available");

  struct ObjCClassCompiled {
    void *Metaclass;
    void *Parent;
    void *Cache1;
    void *Cache2;
    void *Data;
  };

  auto *ImageInfo =
    jitTargetAddressToPointer<const objc_image_info *>(
        MOJDIs.getObjCImageInfoAddr());
  auto ClassSelector = sel_registerName("class");

  for (const auto &ObjCClassList : MOJDIs.getObjCClassListSections()) {
    for (uint64_t I = 0; I != ObjCClassList.NumPtrs; ++I) {
      auto ClassPtrAddr = ObjCClassList.Address + (I * sizeof(uintptr_t));
      auto Cls = *jitTargetAddressToPointer<Class *>(ClassPtrAddr);
      auto *ClassCompiled =
          *jitTargetAddressToPointer<ObjCClassCompiled **>(ClassPtrAddr);
      objc_msgSend(reinterpret_cast<id>(ClassCompiled->Parent), ClassSelector);
      auto Registered = objc_readClassPair(Cls, ImageInfo);

      // FIXME: Improve diagnostic by reporting the failed class's name.
      if (Registered != Cls)
        return make_error<StringError>("Unable to register Objective-C class",
                                       inconvertibleErrorCode());
    }
  }
  return Error::success();
}

void runModInits(const MachOJITDylibInitializers &MOJDIs) {
  for (const auto &ModInit : MOJDIs.getModInitsSections()) {
    for (uint64_t I = 0; I != ModInit.NumPtrs; ++I) {
      auto *InitializerAddr = jitTargetAddressToPointer<uintptr_t *>(
          ModInit.Address + (I * sizeof(uintptr_t)));
      auto *Initializer =
          jitTargetAddressToFunction<void (*)()>(*InitializerAddr);
      Initializer();
    }
  }
}

// NOTE: This is a helper for __orc_rt_macho_dlopen and must be run while
//       holding the lock on JDRS.
static Error machoJITDLOpenHandleOneJITDylib(
    JITDylibRuntimeState &JDRS,
    MachOJITDylibInitializers &MOJDIs) {
  auto &JDS = JDRS.PerJDState[MOJDIs.getName()];
  ++JDS.RefCount;
  if (JDS.Header) {
    // FIXME: Sanity check for header at expected address?
  } else
    JDS.Header = jitTargetAddressToPointer<void*>(MOJDIs.getMachOHeader());

  registerObjCSelectors(MOJDIs);
  if (auto Err = registerObjCClasses(MOJDIs))
    return Err;
  runModInits(MOJDIs);

  return Error::success();
}

static Expected<void *> machoJITDLOpenSlowPath(JITDylibRuntimeState &JDRS,
                                               const char *path, int mode) {
  // Either our JITDylib wasn't loaded, or it or one of its dependencies allows
  // reinitialization. We need to call in to the JIT to see if there's any new
  // work pending.
  auto InitSeq = __orc_rt_macho_get_initializers(path);
  if (!InitSeq)
    return InitSeq.takeError();

  // Init sequences should be non-empty.
  if (InitSeq->empty())
    return make_error<StringError>("__orc_rt_macho_get_initializers returned an "
                                   "empty init sequence",
                                   inconvertibleErrorCode());

  // If ObjC support is not loaded then check that nobody needs it before
  // continuing.
  if (!objc_msgSend || !objc_readClassPair || !sel_registerName) {
    for (auto &IS : *InitSeq) {
      if (!IS.getObjCSelRefsSections().empty() ||
          !IS.getObjCClassListSections().empty()) {
        MachODLFcnError =
          IS.getName() + " requires ObjC support, but libobjc is not loaded";
        return nullptr;
      }
    }
  }

  // Otherwise register and run initializers for each JITDylib.
  for (auto &IS : *InitSeq)
    if (auto Err = machoJITDLOpenHandleOneJITDylib(JDRS, IS))
      return std::move(Err);

  // Return the header for the first item in the list.
  auto I = JDRS.PerJDState.find(InitSeq->front().getName());
  assert(I != JDRS.PerJDState.end() && "Missing state entry for JD");
  return I->second.Header;
}

ORC_RT_INTERFACE const char *__orc_rt_macho_jit_dlerror() {
  return MachODLFcnError.c_str();
}

ORC_RT_INTERFACE void *__orc_rt_macho_jit_dlopen(const char *path, int mode) {
  auto &JDRS = getJITDylibRuntimeState();
  LockGuard Lock(JDRS.JDRuntimeStateMutex);

  // Use fast path if all JITDylibs are already loaded and don't require
  // re-running initializers.
  auto I = JDRS.PerJDState.find(path);
  if (I != JDRS.PerJDState.end() && !I->second.AllowReinitialization) {
    ++I->second.RefCount;
    return I->second.Header;
  }

  auto H = machoJITDLOpenSlowPath(JDRS, path, mode);
  if (!H) {
    MachODLFcnError = toString(H.takeError());
    return nullptr;
  }

  uint32_t V;
  memcpy(&V, *H, sizeof(V));

  return *H;
}

ORC_RT_INTERFACE int __orc_rt_macho_jit_dlclose(void *dso_handle) {
  __orc_rt_cxa_finalize(dso_handle);
  return 0;
}

ORC_RT_INTERFACE void *__orc_rt_macho_jit_dlsym(void *dso_handle,
                                                const char *symbol) {
  auto Addr = __orc_rt_macho_symbol_lookup(dso_handle, symbol);
  if (!Addr) {
    MachODLFcnError = toString(Addr.takeError());
    return 0;
  }

  return jitTargetAddressToPointer<void*>(*Addr);
}
