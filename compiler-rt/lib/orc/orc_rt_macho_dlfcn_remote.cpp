//===-- orc_rt_macho_dlfcn_remote.cpp ---------------------------*- C++ -*-===//
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

extern "C" char __orc_rt_macho_get_initializers_tag = 0;
extern "C" char __orc_rt_macho_get_deinitializers_tag = 0;
extern "C" char __orc_rt_macho_symbol_lookup_tag = 0;

ORC_RT_INTERFACE
Expected<MachOPlatformInitializerSequence>
__orc_rt_macho_get_initializers_remote(const char *path) {
  auto ArgBlob = toWrapperFunctionBlob<std::string>(path);
  auto ResultBlob =
    jit_dispatch(&__orc_rt_macho_get_initializers_tag,
                 ArgBlob.getData());
  if (!ResultBlob)
    return ResultBlob.takeError();

  if (ResultBlob->isEmpty())
    return make_error<StringError>(Twine("Could not get initializers for ") +
                                   path,
                                   inconvertibleErrorCode());

  MachOPlatformInitializerSequence InitSeq;
  if (auto Err = fromWrapperFunctionBlob(ResultBlob->getData(), InitSeq))
    return std::move(Err);

  return std::move(InitSeq);
}

ORC_RT_INTERFACE
Expected<JITTargetAddress>
__orc_rt_macho_symbol_lookup_remote(void *dso_handle, const char *sym) {
  auto ArgBlob =
    toWrapperFunctionBlob<JITTargetAddress, std::string>(
        pointerToJITTargetAddress(dso_handle), sym);
  auto ResultBlob =
    jit_dispatch(&__orc_rt_macho_symbol_lookup_tag, ArgBlob.getData());
  if (!ResultBlob)
    return ResultBlob.takeError();
  if (ResultBlob->isEmpty())
    return make_error<StringError>(Twine("Could not find address for ") + sym,
                                   inconvertibleErrorCode());
  JITTargetAddress Addr;
  if (auto Err = fromWrapperFunctionBlob(ResultBlob->getData(), Addr))
    return std::move(Err);
  return Addr;
}
