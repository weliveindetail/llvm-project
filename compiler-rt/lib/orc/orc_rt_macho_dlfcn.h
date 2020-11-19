//===-- orc_rt_macho_dlfcn.h ------------------------------------*- C++ -*-===//
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

#ifndef ORC_RT_MACHO_DLFCN_H
#define ORC_RT_MACHO_DLFCN_H

#include "orc_rt_common.h"

enum orc_rt_dlopen_mode : int {
  ORC_RT_RTLD_LAZY = 0x1,
  ORC_RT_RTLD_NOW = 0x2,
  ORC_RT_RTLD_LOCAL = 0x4,
  ORC_RT_RTLD_GLOBAL = 0x8
};

ORC_RT_INTERFACE const char *__orc_rt_macho_jit_dlerror();
ORC_RT_INTERFACE void *__orc_rt_macho_jit_dlopen(const char *path, int mode);
ORC_RT_INTERFACE int __orc_rt_macho_jit_dlclose(void *dso_handle);
ORC_RT_INTERFACE void *__orc_rt_macho_jit_dlsym(void *dso_handle, const char *symbol);

#endif // ORC_RT_MACHO_DLFCN_H
