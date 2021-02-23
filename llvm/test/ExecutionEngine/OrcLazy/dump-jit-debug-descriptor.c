//===----- dump-jit-debug-descriptor.c -- C debug info source -----*- C -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// C source of the same-named IR file that implements a test for lli. It is
// referenced as the source file in the IR file's debug info tags and acts as a
// template for regenerating it via:
//
//     clang -c -g -fPIC -emit-llvm -S dump-jit-debug-descriptor.c
//
//===----------------------------------------------------------------------===//

#include "inttypes.h"
#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"

// Declarations follow the GDB JIT interface (version 1, 2009) and must match
// those of the DYLD used for testing. See:
//
//   llvm/lib/ExecutionEngine/Orc/TargetProcess/JITLoaderGDB.cpp
//   llvm/lib/ExecutionEngine/GDBRegistrationListener.cpp
//
typedef enum {
  JIT_NOACTION = 0,
  JIT_REGISTER_FN,
  JIT_UNREGISTER_FN
} jit_actions_t;

struct jit_code_entry {
  struct jit_code_entry *next_entry;
  struct jit_code_entry *prev_entry;
  const char *symfile_addr;
  uint64_t symfile_size;
};

struct jit_descriptor {
  uint32_t version;
  // This should be jit_actions_t, but we want to be specific about the
  // bit-width.
  uint32_t action_flag;
  struct jit_code_entry *relevant_entry;
  struct jit_code_entry *first_entry;
};

// The JIT defines this symbol and injects entries dynamically.
extern struct jit_descriptor __jit_debug_descriptor;

const char *actionFlagToStr(uint32_t ActionFlag) {
  switch (ActionFlag) {
  case JIT_NOACTION:
    return "JIT_NOACTION";
  case JIT_REGISTER_FN:
    return "JIT_REGISTER_FN";
  case JIT_UNREGISTER_FN:
    return "JIT_UNREGISTER_FN";
  }
  return "<invalid action_flag>";
}

// Sample output:
//
//   Reading __jit_debug_descriptor at 0x0000000000404048
//
//   Version: 0
//   Action: JIT_REGISTER_FN
//
//         Entry               Symbol File         Size  Previous Entry
//   [ 0]  0x0000000000451290  0x0000000000002000   200  0x0000000000000000
//   [ 1]  0x0000000000451260  0x0000000000001000   100  0x0000000000451290
//   ...
//
int main() {
  printf("Reading __jit_debug_descriptor at 0x%016" PRIX64 "\n\n",
         (uintptr_t)(&__jit_debug_descriptor));
  printf("Version: %d\n", __jit_debug_descriptor.version);
  printf("Action: %s\n\n", actionFlagToStr(__jit_debug_descriptor.action_flag));

  const char *FmtHead = "%11s  %24s  %15s  %14s\n";
  const char *FmtRow = "[%2d]  0x%016" PRIX64 "  0x%016" PRIX64 "  %8ld  "
                       "0x%016" PRIX64 "\n";

  unsigned Idx = 0;
  struct jit_code_entry *Entry = __jit_debug_descriptor.first_entry;
  printf(FmtHead, "Entry", "Symbol File", "Size", "Previous Entry");
  while (Entry) {
    printf(FmtRow, Idx, (uintptr_t)Entry, (uintptr_t)Entry->symfile_addr,
           Entry->symfile_size, (uintptr_t)Entry->prev_entry);
    Entry = Entry->next_entry;
    Idx += 1;
  }

  return 0;
}
