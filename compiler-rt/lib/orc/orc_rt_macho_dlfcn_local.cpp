//===-- orc_rt_macho_dlfcn_local.cpp ----------------------------*- C++ -*-===//
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
#include "llvm/ExecutionEngine/Orc/Shared/MachOPlatformTypes.h"

using namespace llvm;
using namespace llvm::orc;
using namespace llvm::orc::shared;

using namespace orc_rt;

extern "C" void *__macho_platform = 0;

extern "C" Expected<MachOPlatformInitializerSequence>
__llvm_macho_platform_get_initializers(void *VMOP, const char *Path);

extern "C" Expected<JITTargetAddress>
__llvm_macho_platform_symbol_lookup(void *VMOP, void *DSOHandle,
                                    const char *Sym);

ORC_RT_INTERFACE
Expected<MachOPlatformInitializerSequence>
__orc_rt_macho_get_initializers_local(const char *path) {
  return __llvm_macho_platform_get_initializers(__macho_platform, path);
}

ORC_RT_INTERFACE
Expected<JITTargetAddress>
__orc_rt_macho_symbol_lookup_local(void *dso_handle, const char *sym) {
  return __llvm_macho_platform_symbol_lookup(__macho_platform, dso_handle, sym);
}
