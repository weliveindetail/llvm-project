//===-- orc_rt_macho_run_program.cpp ----------------------------*- C++ -*-===//
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
#include "orc_rt_macho_dlfcn.h"

ORC_RT_INTERFACE int64_t __orc_rt_macho_run_program(int argc, char *argv[]) {
  using MainTy = int (*)(int, char *[]);

  void *H = __orc_rt_macho_jit_dlopen("Main", ORC_RT_RTLD_LAZY);
  if (!H) {
    __orc_rt_log_error(__orc_rt_macho_jit_dlerror());
    return -1;
  }

  auto *Main = reinterpret_cast<MainTy>(__orc_rt_macho_jit_dlsym(H, "main"));

  if (!Main) {
    __orc_rt_log_error(__orc_rt_macho_jit_dlerror());
    return -1;
  }

  int Result = Main(argc, argv);

  if (__orc_rt_macho_jit_dlclose(H) == -1)
    __orc_rt_log_error(__orc_rt_macho_jit_dlerror());

  return Result;
}
