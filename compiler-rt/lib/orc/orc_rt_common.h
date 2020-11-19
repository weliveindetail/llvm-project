//===-- orc_rt_common.h -----------------------------------------*- C++ -*-===//
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

#ifndef ORC_RT_COMMON_H
#define ORC_RT_COMMON_H

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <pthread.h>
#include <type_traits>

#include "llvm/ExecutionEngine/Orc/Shared/WrapperFunctionUtils.h"

#define ORC_RT_INTERFACE extern "C" __attribute__((visibility("default")))

/// Opaque struct for external symbols.
struct Opaque {};

/// Context object for dispatching calls to the JIT object.
extern "C" Opaque __orc_rt_jit_dispatch_remote_ctx __attribute__((weak_import));

/// For dispatching calls to the JIT object.
extern "C" LLVMOrcSharedCWrapperFunctionResult
__orc_rt_jit_dispatch_remote(Opaque *DispatchCtx, const void *FnTag,
                             const uint8_t *Data, size_t Size);

/// Error reporting function.
extern "C" void __orc_rt_log_error(const char *ErrMsg);

namespace orc_rt {

/// Must be kept in sync with JITSymbol.h
using JITTargetAddress = uint64_t;

/// Cast from JITTargetAddress to pointer.
template <typename T> T jitTargetAddressToPointer(JITTargetAddress Addr) {
  static_assert(std::is_pointer<T>::value, "T must be a pointer type");
  return reinterpret_cast<T>(static_cast<uintptr_t>(Addr));
}

/// Convert a JITTargetAddress to a callable function pointer.
template <typename T> T jitTargetAddressToFunction(JITTargetAddress Addr) {
  static_assert(std::is_pointer<T>::value &&
                    std::is_function<std::remove_pointer_t<T>>::value,
                "T must be a function pointer type");
  return jitTargetAddressToPointer<T>(Addr);
}

/// Cast from pointer to JITTargetAddress.
template <typename T> JITTargetAddress pointerToJITTargetAddress(T *Ptr) {
  return static_cast<JITTargetAddress>(reinterpret_cast<uintptr_t>(Ptr));
}

/// Convenience function for dispatching via __orc_rt_jit_dispatch_remote.
/// Automatically checks that remote context has been set and throws an error
/// if not.
inline llvm::Expected<llvm::orc::shared::WrapperFunctionResult>
jit_dispatch(const void *FnTag, llvm::ArrayRef<uint8_t> ArgBuffer) {
  if (&__orc_rt_jit_dispatch_remote_ctx == 0)
    return llvm::make_error<llvm::StringError>(
        "__orc_rt_jit_dispatch_remote_ctx not set",
        llvm::inconvertibleErrorCode());

  llvm::orc::shared::WrapperFunctionResult WFR =
      __orc_rt_jit_dispatch_remote(&__orc_rt_jit_dispatch_remote_ctx, FnTag,
                                   ArgBuffer.data(), ArgBuffer.size());
  if (auto Err = WFR.getAnyOutOfBandError())
    return std::move(Err);
  return std::move(WFR);
}

/// RAII lock for pthread mutexes.
class LockGuard {
public:
  LockGuard(pthread_mutex_t &M) : M(M) { pthread_mutex_lock(&M); }
  LockGuard(const LockGuard &) = delete;
  LockGuard &operator=(const LockGuard &) = delete;
  ~LockGuard() { pthread_mutex_unlock(&M); }
private:
  pthread_mutex_t &M;
};

} // end namespace orc_rt

#endif // ORC_RT_COMMON_H
