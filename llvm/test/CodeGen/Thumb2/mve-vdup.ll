; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=thumbv8.1m.main-arm-none-eabi -mattr=+mve,+fullfp16 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=thumbv8.1m.main-arm-none-eabi -mattr=+mve.fp -verify-machineinstrs %s -o - | FileCheck %s

define arm_aapcs_vfpcc <4 x i32> @vdup_i32(i32 %src) {
; CHECK-LABEL: vdup_i32:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vdup.32 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <4 x i32> undef, i32 %src, i32 0
  %out = shufflevector <4 x i32> %0, <4 x i32> undef, <4 x i32> zeroinitializer
  ret <4 x i32> %out
}

define arm_aapcs_vfpcc <8 x i16> @vdup_i16(i16 %src) {
; CHECK-LABEL: vdup_i16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vdup.16 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <8 x i16> undef, i16 %src, i32 0
  %out = shufflevector <8 x i16> %0, <8 x i16> undef, <8 x i32> zeroinitializer
  ret <8 x i16> %out
}

define arm_aapcs_vfpcc <16 x i8> @vdup_i8(i8 %src) {
; CHECK-LABEL: vdup_i8:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vdup.8 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <16 x i8> undef, i8 %src, i32 0
  %out = shufflevector <16 x i8> %0, <16 x i8> undef, <16 x i32> zeroinitializer
  ret <16 x i8> %out
}

define arm_aapcs_vfpcc <2 x i64> @vdup_i64(i64 %src) {
; CHECK-LABEL: vdup_i64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.32 q0[0], r0
; CHECK-NEXT:    vmov.32 q0[1], r1
; CHECK-NEXT:    vmov.32 q0[2], r0
; CHECK-NEXT:    vmov.32 q0[3], r1
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <2 x i64> undef, i64 %src, i32 0
  %out = shufflevector <2 x i64> %0, <2 x i64> undef, <2 x i32> zeroinitializer
  ret <2 x i64> %out
}

define arm_aapcs_vfpcc <4 x float> @vdup_f32_1(float %src) {
; CHECK-LABEL: vdup_f32_1:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov r0, s0
; CHECK-NEXT:    vdup.32 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <4 x float> undef, float %src, i32 0
  %out = shufflevector <4 x float> %0, <4 x float> undef, <4 x i32> zeroinitializer
  ret <4 x float> %out
}

define arm_aapcs_vfpcc <4 x float> @vdup_f32_2(float %src1, float %src2) {
; CHECK-LABEL: vdup_f32_2:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vadd.f32 s0, s0, s1
; CHECK-NEXT:    vmov r0, s0
; CHECK-NEXT:    vdup.32 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = fadd float %src1, %src2
  %1 = insertelement <4 x float> undef, float %0, i32 0
  %out = shufflevector <4 x float> %1, <4 x float> undef, <4 x i32> zeroinitializer
  ret <4 x float> %out
}

; TODO: Calling convention needs fixing to pass half types directly to functions
define arm_aapcs_vfpcc <8 x half> @vdup_f16(half* %src1, half* %src2) {
; CHECK-LABEL: vdup_f16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vldr.16 s0, [r1]
; CHECK-NEXT:    vldr.16 s2, [r0]
; CHECK-NEXT:    vadd.f16 s0, s2, s0
; CHECK-NEXT:    vmov.f16 r0, s0
; CHECK-NEXT:    vdup.16 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %0 = load half, half *%src1, align 2
  %1 = load half, half *%src2, align 2
  %2 = fadd half %0, %1
  %3 = insertelement <8 x half> undef, half %2, i32 0
  %out = shufflevector <8 x half> %3, <8 x half> undef, <8 x i32> zeroinitializer
  ret <8 x half> %out
}

define arm_aapcs_vfpcc <2 x double> @vdup_f64(double %src) {
; CHECK-LABEL: vdup_f64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    @ kill: def $d0 killed $d0 def $q0
; CHECK-NEXT:    vmov.f32 s2, s0
; CHECK-NEXT:    vmov.f32 s3, s1
; CHECK-NEXT:    bx lr
entry:
  %0 = insertelement <2 x double> undef, double %src, i32 0
  %out = shufflevector <2 x double> %0, <2 x double> undef, <2 x i32> zeroinitializer
  ret <2 x double> %out
}



define arm_aapcs_vfpcc <4 x i32> @vduplane_i32(<4 x i32> %src) {
; CHECK-LABEL: vduplane_i32:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.32 r0, q0[3]
; CHECK-NEXT:    vdup.32 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <4 x i32> %src, <4 x i32> undef, <4 x i32> <i32 3, i32 3, i32 3, i32 3>
  ret <4 x i32> %out
}

define arm_aapcs_vfpcc <8 x i16> @vduplane_i16(<8 x i16> %src) {
; CHECK-LABEL: vduplane_i16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.u16 r0, q0[3]
; CHECK-NEXT:    vdup.16 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <8 x i16> %src, <8 x i16> undef, <8 x i32> <i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3>
  ret <8 x i16> %out
}

define arm_aapcs_vfpcc <16 x i8> @vduplane_i8(<16 x i8> %src) {
; CHECK-LABEL: vduplane_i8:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.u8 r0, q0[3]
; CHECK-NEXT:    vdup.8 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <16 x i8> %src, <16 x i8> undef, <16 x i32> <i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3>
  ret <16 x i8> %out
}

define arm_aapcs_vfpcc <2 x i64> @vduplane_i64(<2 x i64> %src) {
; CHECK-LABEL: vduplane_i64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.f32 s0, s2
; CHECK-NEXT:    vmov.f32 s1, s3
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <2 x i64> %src, <2 x i64> undef, <2 x i32> <i32 1, i32 1>
  ret <2 x i64> %out
}

define arm_aapcs_vfpcc <4 x float> @vduplane_f32(<4 x float> %src) {
; CHECK-LABEL: vduplane_f32:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.32 r0, q0[3]
; CHECK-NEXT:    vdup.32 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <4 x float> %src, <4 x float> undef, <4 x i32> <i32 3, i32 3, i32 3, i32 3>
  ret <4 x float> %out
}

define arm_aapcs_vfpcc <8 x half> @vduplane_f16(<8 x half> %src) {
; CHECK-LABEL: vduplane_f16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.u16 r0, q0[3]
; CHECK-NEXT:    vdup.16 q0, r0
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <8 x half> %src, <8 x half> undef, <8 x i32> <i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3>
  ret <8 x half> %out
}

define arm_aapcs_vfpcc <2 x double> @vduplane_f64(<2 x double> %src) {
; CHECK-LABEL: vduplane_f64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vmov.f32 s0, s2
; CHECK-NEXT:    vmov.f32 s1, s3
; CHECK-NEXT:    bx lr
entry:
  %out = shufflevector <2 x double> %src, <2 x double> undef, <2 x i32> <i32 1, i32 1>
  ret <2 x double> %out
}
