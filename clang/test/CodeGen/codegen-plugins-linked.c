// Bye linked into clang as a static extension provides its PreCodeGenCallback
// without -fpass-plugin, both in regular codegen and with -fthinlto-index.
// REQUIRES: linked-bye
// Bye is not built on Windows.
// UNSUPPORTED: target={{.*windows.*}}

// RUN: %clang_cc1 -S < %s -o - 2>&1 | FileCheck %s --check-prefix=CHECK-INACTIVE
// RUN: %clang_cc1 -S < %s -o - -mllvm -last-words | FileCheck %s --check-prefix=CHECK-ACTIVE
// RUN: not %clang_cc1 -emit-obj < %s -o - -mllvm -last-words 2>&1 | FileCheck %s --check-prefix=CHECK-ERR

// RUN: %clang_cc1 -O2 -flto=thin -emit-llvm-bc %s -o %t.o
// RUN: llvm-lto -thinlto -o %t %t.o
// RUN: %clang_cc1 -O2 -x ir %t.o -fthinlto-index=%t.thinlto.bc -S -o - 2>&1 | FileCheck %s --check-prefix=CHECK-INACTIVE
// RUN: %clang_cc1 -O2 -x ir %t.o -fthinlto-index=%t.thinlto.bc -S -o - -mllvm -last-words | FileCheck %s --check-prefix=CHECK-ACTIVE
// RUN: not %clang_cc1 -O2 -x ir %t.o -fthinlto-index=%t.thinlto.bc -emit-obj -o - -mllvm -last-words 2>&1 | FileCheck %s --check-prefix=CHECK-ERR

// CHECK-INACTIVE-NOT: Bye
// CHECK-INACTIVE: f:
// CHECK-ACTIVE: CodeGen Bye
// CHECK-ERR: error: last words unsupported for binary output

int f(int x) {
  return x;
}
