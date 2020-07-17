; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -ppc-asm-full-reg-names -ppc-vsr-nums-as-vr -verify-machineinstrs -mcpu=pwr8 -mattr=+vsx \
; RUN:   -mtriple=powerpc64le-unknown-linux-gnu < %s | FileCheck %s --check-prefix=CHECK-P8

; RUN: llc -ppc-asm-full-reg-names -ppc-vsr-nums-as-vr -verify-machineinstrs -mcpu=pwr9 -mattr=+vsx \
; RUN:   -mtriple=powerpc64le-unknown-linux-gnu < %s | FileCheck %s --check-prefix=CHECK-P9

; RUN: llc -ppc-asm-full-reg-names -ppc-vsr-nums-as-vr -verify-machineinstrs -mcpu=pwr8 -mattr=+vsx \
; RUN:   -mtriple=powerpc64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=CHECK-P8-BE

; RUN: llc -ppc-asm-full-reg-names -ppc-vsr-nums-as-vr -verify-machineinstrs -mcpu=pwr9 -mattr=+vsx \
; RUN:   -mtriple=powerpc64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=CHECK-P9-BE

define <2 x i64> @load_swap00(<2 x i64>* %vp1, <2 x i64>* %vp2) {
; CHECK-P8-LABEL: load_swap00:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    lxvd2x v2, 0, r3
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap00:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvd2x v2, 0, r3
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap00:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    lxvd2x v2, 0, r3
; CHECK-P8-BE-NEXT:    xxswapd v2, v2
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap00:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv v2, 0(r3)
; CHECK-P9-BE-NEXT:    xxswapd v2, v2
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <2 x i64>, <2 x i64>* %vp1
  %v2 = load <2 x i64>, <2 x i64>* %vp2
  %v3 = shufflevector <2 x i64> %v1, <2 x i64> %v2, <2 x i32> <i32 1, i32 0>
  ret <2 x i64> %v3
}

define <2 x i64> @load_swap01(<2 x i64>* %vp1, <2 x i64>* %vp2) {
; CHECK-P8-LABEL: load_swap01:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    lxvd2x v2, 0, r4
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap01:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvd2x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap01:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    lxvd2x v2, 0, r4
; CHECK-P8-BE-NEXT:    xxswapd v2, v2
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap01:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv v2, 0(r4)
; CHECK-P9-BE-NEXT:    xxswapd v2, v2
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <2 x i64>, <2 x i64>* %vp1
  %v2 = load <2 x i64>, <2 x i64>* %vp2
  %v3 = shufflevector <2 x i64> %v1, <2 x i64> %v2, <2 x i32> <i32 3, i32 2>
  ret <2 x i64> %v3
}

define <4 x i32> @load_swap10(<4 x i32>* %vp1, <4 x i32>* %vp2) {
; CHECK-P8-LABEL: load_swap10:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r4, r2, .LCPI2_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    addi r4, r4, .LCPI2_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r4
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap10:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvw4x v2, 0, r3
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap10:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r4, r2, .LCPI2_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    addi r4, r4, .LCPI2_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r4
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap10:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv v2, 0(r3)
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI2_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI2_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <4 x i32>, <4 x i32>* %vp1
  %v2 = load <4 x i32>, <4 x i32>* %vp2
  %v3 = shufflevector <4 x i32> %v1, <4 x i32> %v2, <4 x i32> <i32 3, i32 2, i32 1, i32 0>
  ret <4 x i32> %v3
}

define <4 x i32> @load_swap11(<4 x i32>* %vp1, <4 x i32>* %vp2) {
; CHECK-P8-LABEL: load_swap11:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI3_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r4
; CHECK-P8-NEXT:    addi r3, r3, .LCPI3_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap11:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvw4x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap11:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI3_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r4
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI3_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap11:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI3_0@toc@ha
; CHECK-P9-BE-NEXT:    lxv v2, 0(r4)
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI3_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <4 x i32>, <4 x i32>* %vp1
  %v2 = load <4 x i32>, <4 x i32>* %vp2
  %v3 = shufflevector <4 x i32> %v1, <4 x i32> %v2, <4 x i32> <i32 7, i32 6, i32 5, i32 4>
  ret <4 x i32> %v3
}

define <8 x i16> @load_swap20(<8 x i16>* %vp1, <8 x i16>* %vp2){
; CHECK-P8-LABEL: load_swap20:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r4, r2, .LCPI4_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    addi r4, r4, .LCPI4_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r4
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap20:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvh8x v2, 0, r3
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap20:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r4, r2, .LCPI4_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    addi r4, r4, .LCPI4_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r4
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap20:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv v2, 0(r3)
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI4_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI4_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <8 x i16>, <8 x i16>* %vp1
  %v2 = load <8 x i16>, <8 x i16>* %vp2
  %v3 = shufflevector <8 x i16> %v1, <8 x i16> %v2, <8 x i32> <i32 7, i32 6, i32 5, i32 4, i32 3, i32 2, i32 1, i32 0>
  ret <8 x i16> %v3
}

define <8 x i16> @load_swap21(<8 x i16>* %vp1, <8 x i16>* %vp2){
; CHECK-P8-LABEL: load_swap21:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI5_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r4
; CHECK-P8-NEXT:    addi r3, r3, .LCPI5_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap21:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvh8x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap21:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI5_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r4
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI5_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap21:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI5_0@toc@ha
; CHECK-P9-BE-NEXT:    lxv v2, 0(r4)
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI5_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <8 x i16>, <8 x i16>* %vp1
  %v2 = load <8 x i16>, <8 x i16>* %vp2
  %v3 = shufflevector <8 x i16> %v1, <8 x i16> %v2, <8 x i32> <i32 15, i32 14, i32 13, i32 12, i32 11, i32 10, i32 9, i32 8>
  ret <8 x i16> %v3
}

define <16 x i8> @load_swap30(<16 x i8>* %vp1, <16 x i8>* %vp2){
; CHECK-P8-LABEL: load_swap30:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r4, r2, .LCPI6_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    addi r4, r4, .LCPI6_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r4
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap30:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvb16x v2, 0, r3
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap30:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r4, r2, .LCPI6_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    addi r4, r4, .LCPI6_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r4
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap30:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv vs0, 0(r3)
; CHECK-P9-BE-NEXT:    xxbrq v2, vs0
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <16 x i8>, <16 x i8>* %vp1
  %v2 = load <16 x i8>, <16 x i8>* %vp2
  %v3 = shufflevector <16 x i8> %v1, <16 x i8> %v2, <16 x i32> <i32 15, i32 14, i32 13, i32 12, i32 11, i32 10, i32 9, i32 8, i32 7, i32 6, i32 5, i32 4, i32 3, i32 2, i32 1, i32 0>
  ret <16 x i8> %v3
}

define <16 x i8> @load_swap31(<16 x i8>* %vp1, <16 x i8>* %vp2){
; CHECK-P8-LABEL: load_swap31:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI7_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r4
; CHECK-P8-NEXT:    addi r3, r3, .LCPI7_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap31:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvb16x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap31:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI7_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r4
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI7_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap31:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv vs0, 0(r4)
; CHECK-P9-BE-NEXT:    xxbrq v2, vs0
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <16 x i8>, <16 x i8>* %vp1
  %v2 = load <16 x i8>, <16 x i8>* %vp2
  %v3 = shufflevector <16 x i8> %v1, <16 x i8> %v2, <16 x i32> <i32 31, i32 30, i32 29, i32 28, i32 27, i32 26, i32 25, i32 24, i32 23, i32 22, i32 21, i32 20, i32 19, i32 18, i32 17, i32 16>
  ret <16 x i8> %v3
}

define <2 x double> @load_swap40(<2 x double>* %vp1, <2 x double>* %vp2) {
; CHECK-P8-LABEL: load_swap40:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    lxvd2x v2, 0, r4
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap40:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvd2x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap40:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    lxvd2x vs0, 0, r4
; CHECK-P8-BE-NEXT:    xxswapd v2, vs0
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap40:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv vs0, 0(r4)
; CHECK-P9-BE-NEXT:    xxswapd v2, vs0
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <2 x double>, <2 x double>* %vp1
  %v2 = load <2 x double>, <2 x double>* %vp2
  %v3 = shufflevector <2 x double> %v1, <2 x double> %v2, <2 x i32> <i32 3, i32 2>
  ret <2 x double> %v3
}

define <4 x float> @load_swap50(<4 x float>* %vp1, <4 x float>* %vp2) {
; CHECK-P8-LABEL: load_swap50:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r4, r2, .LCPI9_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    addi r4, r4, .LCPI9_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r4
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap50:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvw4x v2, 0, r3
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap50:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r4, r2, .LCPI9_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    addi r4, r4, .LCPI9_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r4
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap50:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    lxv v2, 0(r3)
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI9_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI9_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <4 x float>, <4 x float>* %vp1
  %v2 = load <4 x float>, <4 x float>* %vp2
  %v3 = shufflevector <4 x float> %v1, <4 x float> %v2, <4 x i32> <i32 3, i32 2, i32 1, i32 0>
  ret <4 x float> %v3
}

define <4 x float> @load_swap51(<4 x float>* %vp1, <4 x float>* %vp2) {
; CHECK-P8-LABEL: load_swap51:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI10_0@toc@ha
; CHECK-P8-NEXT:    lvx v3, 0, r4
; CHECK-P8-NEXT:    addi r3, r3, .LCPI10_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: load_swap51:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    lxvw4x v2, 0, r4
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: load_swap51:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI10_0@toc@ha
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r4
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI10_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: load_swap51:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI10_0@toc@ha
; CHECK-P9-BE-NEXT:    lxv v2, 0(r4)
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI10_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    blr
  %v1 = load <4 x float>, <4 x float>* %vp1
  %v2 = load <4 x float>, <4 x float>* %vp2
  %v3 = shufflevector <4 x float> %v1, <4 x float> %v2, <4 x i32> <i32 7, i32 6, i32 5, i32 4>
  ret <4 x float> %v3
}

define void @swap_store00(<2 x i64> %v1, <2 x i64> %v2, <2 x i64>* %vp) {
; CHECK-P8-LABEL: swap_store00:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    stxvd2x v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store00:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvd2x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store00:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    xxswapd vs0, v2
; CHECK-P8-BE-NEXT:    stxvd2x vs0, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store00:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxswapd vs0, v2
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <2 x i64> %v1, <2 x i64> %v2, <2 x i32> <i32 1, i32 0>
  store <2 x i64> %v3, <2 x i64>* %vp
  ret void
}

define void @swap_store01(<2 x i64> %v1, <2 x i64> %v2, <2 x i64>* %vp) {
; CHECK-P8-LABEL: swap_store01:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    stxvd2x v3, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store01:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvd2x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store01:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    xxswapd vs0, v3
; CHECK-P8-BE-NEXT:    stxvd2x vs0, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store01:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxswapd vs0, v3
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <2 x i64> %v1, <2 x i64> %v2, <2 x i32> <i32 3, i32 2>
  store <2 x i64> %v3, <2 x i64>* %vp
  ret void
}

define void @swap_store10(<4 x i32> %v1, <4 x i32> %v2, <4 x i32>* %vp) {
; CHECK-P8-LABEL: swap_store10:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI13_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI13_0@toc@l
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store10:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvw4x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store10:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI13_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI13_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store10:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI13_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI13_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <4 x i32> %v1, <4 x i32> %v2, <4 x i32> <i32 3, i32 2, i32 1, i32 0>
  store <4 x i32> %v3, <4 x i32>* %vp
  ret void
}

define void @swap_store11(<4 x i32> %v1, <4 x i32> %v2, <4 x i32>* %vp) {
; CHECK-P8-LABEL: swap_store11:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI14_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI14_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store11:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvw4x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store11:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI14_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI14_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store11:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI14_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI14_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v2, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <4 x i32> %v1, <4 x i32> %v2, <4 x i32> <i32 7, i32 6, i32 5, i32 4>
  store <4 x i32> %v3, <4 x i32>* %vp
  ret void
}

define void @swap_store20(<8 x i16> %v1, <8 x i16> %v2, <8 x i16>* %vp) {
; CHECK-P8-LABEL: swap_store20:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI15_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI15_0@toc@l
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store20:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvh8x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store20:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI15_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI15_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store20:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI15_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI15_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <8 x i16> %v1, <8 x i16> %v2, <8 x i32> <i32 7, i32 6, i32 5, i32 4, i32 3, i32 2, i32 1, i32 0>
  store <8 x i16> %v3, <8 x i16>* %vp
  ret void
}

define void @swap_store21(<8 x i16> %v1, <8 x i16> %v2, <8 x i16>* %vp) {
; CHECK-P8-LABEL: swap_store21:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI16_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI16_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store21:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvh8x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store21:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI16_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI16_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store21:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI16_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI16_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v2, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <8 x i16> %v1, <8 x i16> %v2, <8 x i32> <i32 15, i32 14, i32 13, i32 12, i32 11, i32 10, i32 9, i32 8>
  store <8 x i16> %v3, <8 x i16>* %vp
  ret void
}

define void @swap_store30(<16 x i8> %v1, <16 x i8> %v2, <16 x i8>* %vp) {
; CHECK-P8-LABEL: swap_store30:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI17_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI17_0@toc@l
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store30:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvb16x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store30:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI17_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI17_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store30:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxbrq vs0, v2
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <16 x i8> %v1, <16 x i8> %v2, <16 x i32> <i32 15, i32 14, i32 13, i32 12, i32 11, i32 10, i32 9, i32 8, i32 7, i32 6, i32 5, i32 4, i32 3, i32 2, i32 1, i32 0>
  store <16 x i8> %v3, <16 x i8>* %vp
  ret void
}

define void @swap_store31(<16 x i8> %v1, <16 x i8> %v2, <16 x i8>* %vp) {
; CHECK-P8-LABEL: swap_store31:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI18_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI18_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store31:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvb16x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store31:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI18_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI18_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store31:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxbrq vs0, v3
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <16 x i8> %v1, <16 x i8> %v2, <16 x i32> <i32 31, i32 30, i32 29, i32 28, i32 27, i32 26, i32 25, i32 24, i32 23, i32 22, i32 21, i32 20, i32 19, i32 18, i32 17, i32 16>
  store <16 x i8> %v3, <16 x i8>* %vp
  ret void
}

define void @swap_store40(<2 x double> %v1, <2 x double> %v2, <2 x double>* %vp) {
; CHECK-P8-LABEL: swap_store40:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    stxvd2x v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store40:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvd2x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store40:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    xxswapd vs0, v2
; CHECK-P8-BE-NEXT:    stxvd2x vs0, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store40:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxswapd vs0, v2
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <2 x double> %v1, <2 x double> %v2, <2 x i32> <i32 1, i32 0>
  store <2 x double> %v3, <2 x double>* %vp
  ret void
}

define void @swap_store41(<2 x double> %v1, <2 x double> %v2, <2 x double>* %vp) {
; CHECK-P8-LABEL: swap_store41:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    stxvd2x v3, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store41:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvd2x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store41:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    xxswapd vs0, v3
; CHECK-P8-BE-NEXT:    stxvd2x vs0, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store41:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    xxswapd vs0, v3
; CHECK-P9-BE-NEXT:    stxv vs0, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <2 x double> %v1, <2 x double> %v2, <2 x i32> <i32 3, i32 2>
  store <2 x double> %v3, <2 x double>* %vp
  ret void
}

define void @swap_store50(<4 x float> %v1, <4 x float> %v2, <4 x float>* %vp) {
; CHECK-P8-LABEL: swap_store50:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI21_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI21_0@toc@l
; CHECK-P8-NEXT:    lvx v3, 0, r3
; CHECK-P8-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store50:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvw4x v2, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store50:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI21_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI21_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v3, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store50:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI21_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI21_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v3, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v2, v2, v3
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <4 x float> %v1, <4 x float> %v2, <4 x i32> <i32 3, i32 2, i32 1, i32 0>
  store <4 x float> %v3, <4 x float>* %vp
  ret void
}

define void @swap_store51(<4 x float> %v1, <4 x float> %v2, <4 x float>* %vp) {
; CHECK-P8-LABEL: swap_store51:
; CHECK-P8:       # %bb.0:
; CHECK-P8-NEXT:    addis r3, r2, .LCPI22_0@toc@ha
; CHECK-P8-NEXT:    addi r3, r3, .LCPI22_0@toc@l
; CHECK-P8-NEXT:    lvx v2, 0, r3
; CHECK-P8-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-NEXT:    stvx v2, 0, r7
; CHECK-P8-NEXT:    blr
;
; CHECK-P9-LABEL: swap_store51:
; CHECK-P9:       # %bb.0:
; CHECK-P9-NEXT:    stxvw4x v3, 0, r7
; CHECK-P9-NEXT:    blr
;
; CHECK-P8-BE-LABEL: swap_store51:
; CHECK-P8-BE:       # %bb.0:
; CHECK-P8-BE-NEXT:    addis r3, r2, .LCPI22_0@toc@ha
; CHECK-P8-BE-NEXT:    addi r3, r3, .LCPI22_0@toc@l
; CHECK-P8-BE-NEXT:    lxvw4x v2, 0, r3
; CHECK-P8-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P8-BE-NEXT:    stxvw4x v2, 0, r7
; CHECK-P8-BE-NEXT:    blr
;
; CHECK-P9-BE-LABEL: swap_store51:
; CHECK-P9-BE:       # %bb.0:
; CHECK-P9-BE-NEXT:    addis r3, r2, .LCPI22_0@toc@ha
; CHECK-P9-BE-NEXT:    addi r3, r3, .LCPI22_0@toc@l
; CHECK-P9-BE-NEXT:    lxvx v2, 0, r3
; CHECK-P9-BE-NEXT:    vperm v2, v3, v3, v2
; CHECK-P9-BE-NEXT:    stxv v2, 0(r7)
; CHECK-P9-BE-NEXT:    blr
  %v3 = shufflevector <4 x float> %v1, <4 x float> %v2, <4 x i32> <i32 7, i32 6, i32 5, i32 4>
  store <4 x float> %v3, <4 x float>* %vp
  ret void
}
