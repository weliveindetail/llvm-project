// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -emit-llvm -fobjc-arc -fexceptions -fobjc-exceptions -fobjc-runtime=gnustep-2.0 -o - %s | FileCheck %s

@class Ety;
void opaque(void);
void test_catch_preisel_intrinsic(void) {
  @try {
    opaque();
  } @catch (Ety *ex) {
    // Destroy ex when leaving catchpad. Emits calls to two intrinsic functions,
    // that should both have a "funclet" bundle operand that refers to the
    // catchpad's SSA value.
  }
}

// CHECK-LABEL: define{{.*}} void {{.*}}test_catch_preisel_intrinsic
//                ...
// CHECK:       catch.dispatch:
// CHECK-NEXT:    [[CATCHSWITCH:%[0-9]+]] = catchswitch within none
//                ...
// CHECK:       catch:
// CHECK-NEXT:    [[CATCHPAD:%[0-9]+]] = catchpad within [[CATCHSWITCH]]
// CHECK:         {{%[0-9]+}} = call {{.*}} @llvm.objc.retain{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
// CHECK:         call {{.*}} @llvm.objc.storeStrong{{.*}} [ "funclet"(token [[CATCHPAD]]) ]
