// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -emit-llvm -fobjc-arc -fexceptions -fobjc-exceptions -fobjc-runtime=gnustep-2.0 -o - %s | FileCheck %s

// WinEH requires funclet tokens on nounwind intrinsics if they can lower to
// regular function calls in the course of IR transformations.
//
// This is the case for ObjC ARC runtime intrinsics. Test that:
// (1) Clang emits funclet tokens for llvm.objc.* calls
// (2) All such calls are between catchpad and catchret/unreachable
// (3) Funclet tokens refer to their catchpad's SSA value

@class Ety;
void opaque(void);
void do_rethrow() {
  @try {
    opaque();
  } @catch (Ety *ex) {
    @throw ex;
  }
}
void test_catch_with_objc_intrinsic(void) {
  @try {
    do_rethrow();
  } @catch (Ety *ex) {
    // Destroy ex when leaving catchpad. This would emit calls to two
    // intrinsic functions: llvm.objc.retain and llvm.objc.storeStrong
  }
}

// CHECK-LABEL: do_rethrow
//                ...
// CHECK:       catch.dispatch:
// CHECK-NEXT:    [[CATCHSWITCH:%[0-9]+]] = catchswitch within none [label %catch]
//                ...
// CHECK:       catch:
// CHECK-NEXT:    [[CATCHPAD:%[0-9]+]] = catchpad within [[CATCHSWITCH]]
// CHECK:         @llvm.objc.retain{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         @llvm.objc.retainAutorelease{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         @objc_exception_throw{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         unreachable

// CHECK-LABEL: test_catch_with_objc_intrinsic
//                ...
// CHECK:       catch.dispatch:
// CHECK-NEXT:    [[CATCHSWITCH:%[0-9]+]] = catchswitch within none [label %catch]
//                ...
// CHECK:       catch:
// CHECK-NEXT:    [[CATCHPAD:%[0-9]+]] = catchpad within [[CATCHSWITCH]]
// CHECK:         @llvm.objc.retain{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         @llvm.objc.storeStrong{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         catchret from [[CATCHPAD]] to label %catchret.dest
