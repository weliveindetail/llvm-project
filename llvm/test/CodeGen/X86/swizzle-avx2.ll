; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -mattr=avx2 | FileCheck %s

; Test that we correctly fold a shuffle that performs a swizzle of another
; shuffle node according to the rule
;  shuffle (shuffle (x, undef, M0), undef, M1) -> shuffle(x, undef, M2)
;
; We only do this if the resulting mask is legal to avoid introducing an
; illegal shuffle that is expanded into a sub-optimal sequence of instructions
; during lowering stage.

; Check that we produce a single vector permute / shuffle in all cases.

define <8 x i32> @swizzle_1(<8 x i32> %v) {
; CHECK-LABEL: swizzle_1:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovdqa {{.*#+}} ymm1 = [1,3,2,0,4,5,6,7]
; CHECK-NEXT:    vpermd %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 3, i32 1, i32 2, i32 0, i32 7, i32 5, i32 6, i32 4>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 1, i32 0, i32 2, i32 3, i32 7, i32 5, i32 6, i32 4>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_2(<8 x i32> %v) {
; CHECK-LABEL: swizzle_2:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpshufd {{.*#+}} ymm0 = ymm0[2,3,0,1,6,7,4,5]
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 6, i32 7, i32 4, i32 5, i32 0, i32 1, i32 2, i32 3>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 6, i32 7, i32 4, i32 5, i32 0, i32 1, i32 2, i32 3>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_3(<8 x i32> %v) {
; CHECK-LABEL: swizzle_3:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpshufd {{.*#+}} ymm0 = ymm0[2,3,0,1,6,7,4,5]
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 4, i32 5, i32 6, i32 7, i32 2, i32 3, i32 0, i32 1>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 4, i32 5, i32 6, i32 7, i32 2, i32 3, i32 0, i32 1>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_4(<8 x i32> %v) {
; CHECK-LABEL: swizzle_4:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovdqa {{.*#+}} ymm1 = [3,1,2,0,6,5,4,7]
; CHECK-NEXT:    vpermd %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 4, i32 7, i32 5, i32 6, i32 3, i32 2, i32 0, i32 1>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 4, i32 7, i32 5, i32 6, i32 3, i32 2, i32 0, i32 1>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_5(<8 x i32> %v) {
; CHECK-LABEL: swizzle_5:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovdqa {{.*#+}} ymm1 = [3,0,1,2,7,6,4,5]
; CHECK-NEXT:    vpermd %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 7, i32 4, i32 6, i32 5, i32 0, i32 2, i32 1, i32 3>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 7, i32 4, i32 6, i32 5, i32 0, i32 2, i32 1, i32 3>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_6(<8 x i32> %v) {
; CHECK-LABEL: swizzle_6:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovdqa {{.*#+}} ymm1 = [3,1,0,2,4,5,6,7]
; CHECK-NEXT:    vpermd %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 2, i32 1, i32 3, i32 0, i32 4, i32 7, i32 6, i32 5>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 2, i32 1, i32 3, i32 0, i32 4, i32 7, i32 6, i32 5>
  ret <8 x i32> %2
}

define <8 x i32> @swizzle_7(<8 x i32> %v) {
; CHECK-LABEL: swizzle_7:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovdqa {{.*#+}} ymm1 = [0,2,3,1,4,5,6,7]
; CHECK-NEXT:    vpermd %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    retq
  %1 = shufflevector <8 x i32> %v, <8 x i32> undef, <8 x i32> <i32 0, i32 3, i32 1, i32 2, i32 5, i32 4, i32 6, i32 7>
  %2 = shufflevector <8 x i32> %1, <8 x i32> undef, <8 x i32> <i32 0, i32 3, i32 1, i32 2, i32 5, i32 4, i32 6, i32 7>
  ret <8 x i32> %2
}

