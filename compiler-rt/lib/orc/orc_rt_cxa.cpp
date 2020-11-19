//===-- orc_rt_cxa.cpp ------------------------------------------*- C++ -*-===//
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

#include "orc_rt_cxa.h"

#include <pthread.h>
#include <unordered_map>
#include <vector>

using namespace orc_rt;

namespace {

struct AtExitEntry {
  void (*Func)(void*);
  void *Arg;
};

using AtExitsVector = std::vector<AtExitEntry>;

pthread_mutex_t AtExitsMutex = PTHREAD_MUTEX_INITIALIZER;
std::unordered_map<void *, AtExitsVector> AtExits;

} // end anonymous namespace

int __orc_rt_cxa_atexit(void (*func) (void *), void *arg,
                        void *dso_handle) {
  // FIXME: Handle out-of-memory errors, returning -1 if OOM.
  LockGuard Lock(AtExitsMutex);
  AtExits[dso_handle].push_back({func, arg});
  return 0;
}

void __orc_rt_cxa_finalize(void *dso_handle) {
  AtExitsVector V;
  {
    LockGuard Lock(AtExitsMutex);
    auto I = AtExits.find(dso_handle);
    if (I != AtExits.end()) {
      V = std::move(I->second);
      AtExits.erase(I);
    }
  }

  while (!V.empty()) {
    auto &AE = V.back();
    AE.Func(AE.Arg);
    V.pop_back();
  }
}
