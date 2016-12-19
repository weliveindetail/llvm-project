; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-apple-darwin -mcpu=knl  | FileCheck %s --check-prefix=ALL --check-prefix=KNL
; RUN: llc < %s -mtriple=x86_64-apple-darwin -mcpu=skx  | FileCheck %s --check-prefix=ALL --check-prefix=SKX

define <16 x float> @sitof32(<16 x i32> %a) nounwind {
; ALL-LABEL: sitof32:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = sitofp <16 x i32> %a to <16 x float>
  ret <16 x float> %b
}

define <8 x double> @sltof864(<8 x i64> %a) {
; KNL-LABEL: sltof864:
; KNL:       ## BB#0:
; KNL-NEXT:    vextracti32x4 $3, %zmm0, %xmm1
; KNL-NEXT:    vpextrq $1, %xmm1, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm2, %xmm2
; KNL-NEXT:    vmovq %xmm1, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm3, %xmm1
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm1 = xmm1[0],xmm2[0]
; KNL-NEXT:    vextracti32x4 $2, %zmm0, %xmm2
; KNL-NEXT:    vpextrq $1, %xmm2, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm3, %xmm3
; KNL-NEXT:    vmovq %xmm2, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm4, %xmm2
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm2 = xmm2[0],xmm3[0]
; KNL-NEXT:    vinsertf128 $1, %xmm1, %ymm2, %ymm1
; KNL-NEXT:    vextracti32x4 $1, %zmm0, %xmm2
; KNL-NEXT:    vpextrq $1, %xmm2, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm4, %xmm3
; KNL-NEXT:    vmovq %xmm2, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm4, %xmm2
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm2 = xmm2[0],xmm3[0]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm4, %xmm3
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm4, %xmm0
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm0 = xmm0[0],xmm3[0]
; KNL-NEXT:    vinsertf128 $1, %xmm2, %ymm0, %ymm0
; KNL-NEXT:    vinsertf64x4 $1, %ymm1, %zmm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sltof864:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtqq2pd %zmm0, %zmm0
; SKX-NEXT:    retq
  %b = sitofp <8 x i64> %a to <8 x double>
  ret <8 x double> %b
}

define <4 x double> @sltof464(<4 x i64> %a) {
; KNL-LABEL: sltof464:
; KNL:       ## BB#0:
; KNL-NEXT:    vextracti128 $1, %ymm0, %xmm1
; KNL-NEXT:    vpextrq $1, %xmm1, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm2, %xmm2
; KNL-NEXT:    vmovq %xmm1, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm3, %xmm1
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm1 = xmm1[0],xmm2[0]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm3, %xmm2
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2sdq %rax, %xmm3, %xmm0
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm0 = xmm0[0],xmm2[0]
; KNL-NEXT:    vinsertf128 $1, %xmm1, %ymm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sltof464:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtqq2pd %ymm0, %ymm0
; SKX-NEXT:    retq
  %b = sitofp <4 x i64> %a to <4 x double>
  ret <4 x double> %b
}

define <2 x float> @sltof2f32(<2 x i64> %a) {
; KNL-LABEL: sltof2f32:
; KNL:       ## BB#0:
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm1, %xmm1
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm2, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[2,3]
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm2, %xmm1
; KNL-NEXT:    vshufps {{.*#+}} xmm0 = xmm0[0,1],xmm1[0,0]
; KNL-NEXT:    retq
;
; SKX-LABEL: sltof2f32:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtqq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %b = sitofp <2 x i64> %a to <2 x float>
  ret <2 x float>%b
}

define <4 x float> @sltof4f32_mem(<4 x i64>* %a) {
; KNL-LABEL: sltof4f32_mem:
; KNL:       ## BB#0:
; KNL-NEXT:    vmovdqu (%rdi), %ymm0
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm1, %xmm1
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm2, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm2[0],xmm1[0],xmm2[2,3]
; KNL-NEXT:    vextracti128 $1, %ymm0, %xmm0
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm3, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm1[0,1],xmm2[0],xmm1[3]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm3, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm1[0,1,2],xmm0[0]
; KNL-NEXT:    retq
;
; SKX-LABEL: sltof4f32_mem:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtqq2psy (%rdi), %xmm0
; SKX-NEXT:    retq
  %a1 = load <4 x i64>, <4 x i64>* %a, align 8
  %b = sitofp <4 x i64> %a1 to <4 x float>
  ret <4 x float>%b
}

define <4 x i64> @f64tosl(<4 x double> %a) {
; KNL-LABEL: f64tosl:
; KNL:       ## BB#0:
; KNL-NEXT:    vextractf128 $1, %ymm0, %xmm1
; KNL-NEXT:    vcvttsd2si %xmm1, %rax
; KNL-NEXT:    vmovq %rax, %xmm2
; KNL-NEXT:    vpermilpd {{.*#+}} xmm1 = xmm1[1,0]
; KNL-NEXT:    vcvttsd2si %xmm1, %rax
; KNL-NEXT:    vmovq %rax, %xmm1
; KNL-NEXT:    vpunpcklqdq {{.*#+}} xmm1 = xmm2[0],xmm1[0]
; KNL-NEXT:    vcvttsd2si %xmm0, %rax
; KNL-NEXT:    vmovq %rax, %xmm2
; KNL-NEXT:    vpermilpd {{.*#+}} xmm0 = xmm0[1,0]
; KNL-NEXT:    vcvttsd2si %xmm0, %rax
; KNL-NEXT:    vmovq %rax, %xmm0
; KNL-NEXT:    vpunpcklqdq {{.*#+}} xmm0 = xmm2[0],xmm0[0]
; KNL-NEXT:    vinserti128 $1, %xmm1, %ymm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: f64tosl:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvttpd2qq %ymm0, %ymm0
; SKX-NEXT:    retq
  %b = fptosi <4 x double> %a to <4 x i64>
  ret <4 x i64> %b
}

define <4 x i64> @f32tosl(<4 x float> %a) {
; KNL-LABEL: f32tosl:
; KNL:       ## BB#0:
; KNL-NEXT:    vpermilps {{.*#+}} xmm1 = xmm0[3,1,2,3]
; KNL-NEXT:    vcvttss2si %xmm1, %rax
; KNL-NEXT:    vmovq %rax, %xmm1
; KNL-NEXT:    vpermilpd {{.*#+}} xmm2 = xmm0[1,0]
; KNL-NEXT:    vcvttss2si %xmm2, %rax
; KNL-NEXT:    vmovq %rax, %xmm2
; KNL-NEXT:    vpunpcklqdq {{.*#+}} xmm1 = xmm2[0],xmm1[0]
; KNL-NEXT:    vcvttss2si %xmm0, %rax
; KNL-NEXT:    vmovq %rax, %xmm2
; KNL-NEXT:    vmovshdup {{.*#+}} xmm0 = xmm0[1,1,3,3]
; KNL-NEXT:    vcvttss2si %xmm0, %rax
; KNL-NEXT:    vmovq %rax, %xmm0
; KNL-NEXT:    vpunpcklqdq {{.*#+}} xmm0 = xmm2[0],xmm0[0]
; KNL-NEXT:    vinserti128 $1, %xmm1, %ymm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: f32tosl:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvttps2qq %xmm0, %ymm0
; SKX-NEXT:    retq
  %b = fptosi <4 x float> %a to <4 x i64>
  ret <4 x i64> %b
}

define <4 x float> @sltof432(<4 x i64> %a) {
; KNL-LABEL: sltof432:
; KNL:       ## BB#0:
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm1, %xmm1
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm2, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm2[0],xmm1[0],xmm2[2,3]
; KNL-NEXT:    vextracti128 $1, %ymm0, %xmm0
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm3, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm1[0,1],xmm2[0],xmm1[3]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtsi2ssq %rax, %xmm3, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm1[0,1,2],xmm0[0]
; KNL-NEXT:    retq
;
; SKX-LABEL: sltof432:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtqq2ps %ymm0, %xmm0
; SKX-NEXT:    retq
  %b = sitofp <4 x i64> %a to <4 x float>
  ret <4 x float> %b
}

define <4 x float> @ultof432(<4 x i64> %a) {
; KNL-LABEL: ultof432:
; KNL:       ## BB#0:
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtusi2ssq %rax, %xmm1, %xmm1
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtusi2ssq %rax, %xmm2, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm2[0],xmm1[0],xmm2[2,3]
; KNL-NEXT:    vextracti128 $1, %ymm0, %xmm0
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtusi2ssq %rax, %xmm3, %xmm2
; KNL-NEXT:    vinsertps {{.*#+}} xmm1 = xmm1[0,1],xmm2[0],xmm1[3]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtusi2ssq %rax, %xmm3, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm1[0,1,2],xmm0[0]
; KNL-NEXT:    retq
;
; SKX-LABEL: ultof432:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtuqq2ps %ymm0, %xmm0
; SKX-NEXT:    retq
  %b = uitofp <4 x i64> %a to <4 x float>
  ret <4 x float> %b
}

define <8 x double> @ultof64(<8 x i64> %a) {
; KNL-LABEL: ultof64:
; KNL:       ## BB#0:
; KNL-NEXT:    vextracti32x4 $3, %zmm0, %xmm1
; KNL-NEXT:    vpextrq $1, %xmm1, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm2, %xmm2
; KNL-NEXT:    vmovq %xmm1, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm3, %xmm1
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm1 = xmm1[0],xmm2[0]
; KNL-NEXT:    vextracti32x4 $2, %zmm0, %xmm2
; KNL-NEXT:    vpextrq $1, %xmm2, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm3, %xmm3
; KNL-NEXT:    vmovq %xmm2, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm4, %xmm2
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm2 = xmm2[0],xmm3[0]
; KNL-NEXT:    vinsertf128 $1, %xmm1, %ymm2, %ymm1
; KNL-NEXT:    vextracti32x4 $1, %zmm0, %xmm2
; KNL-NEXT:    vpextrq $1, %xmm2, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm4, %xmm3
; KNL-NEXT:    vmovq %xmm2, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm4, %xmm2
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm2 = xmm2[0],xmm3[0]
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm4, %xmm3
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    vcvtusi2sdq %rax, %xmm4, %xmm0
; KNL-NEXT:    vunpcklpd {{.*#+}} xmm0 = xmm0[0],xmm3[0]
; KNL-NEXT:    vinsertf128 $1, %xmm2, %ymm0, %ymm0
; KNL-NEXT:    vinsertf64x4 $1, %ymm1, %zmm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: ultof64:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtuqq2pd %zmm0, %zmm0
; SKX-NEXT:    retq
  %b = uitofp <8 x i64> %a to <8 x double>
  ret <8 x double> %b
}

define <16 x i32> @fptosi00(<16 x float> %a) nounwind {
; ALL-LABEL: fptosi00:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttps2dq %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = fptosi <16 x float> %a to <16 x i32>
  ret <16 x i32> %b
}

define <16 x i32> @fptoui00(<16 x float> %a) nounwind {
; ALL-LABEL: fptoui00:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttps2udq %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = fptoui <16 x float> %a to <16 x i32>
  ret <16 x i32> %b
}

define <8 x i32> @fptoui_256(<8 x float> %a) nounwind {
; KNL-LABEL: fptoui_256:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vcvttps2udq %zmm0, %zmm0
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: fptoui_256:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvttps2udq %ymm0, %ymm0
; SKX-NEXT:    retq
  %b = fptoui <8 x float> %a to <8 x i32>
  ret <8 x i32> %b
}

define <4 x i32> @fptoui_128(<4 x float> %a) nounwind {
; KNL-LABEL: fptoui_128:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %ZMM0<def>
; KNL-NEXT:    vcvttps2udq %zmm0, %zmm0
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: fptoui_128:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvttps2udq %xmm0, %xmm0
; SKX-NEXT:    retq
  %b = fptoui <4 x float> %a to <4 x i32>
  ret <4 x i32> %b
}

define <8 x i32> @fptoui01(<8 x double> %a) nounwind {
; ALL-LABEL: fptoui01:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttpd2udq %zmm0, %ymm0
; ALL-NEXT:    retq
  %b = fptoui <8 x double> %a to <8 x i32>
  ret <8 x i32> %b
}

define <4 x i32> @fptoui_256d(<4 x double> %a) nounwind {
; KNL-LABEL: fptoui_256d:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vcvttpd2udq %zmm0, %ymm0
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %YMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: fptoui_256d:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvttpd2udq %ymm0, %xmm0
; SKX-NEXT:    retq
  %b = fptoui <4 x double> %a to <4 x i32>
  ret <4 x i32> %b
}

define <8 x double> @sitof64(<8 x i32> %a) {
; ALL-LABEL: sitof64:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtdq2pd %ymm0, %zmm0
; ALL-NEXT:    retq
  %b = sitofp <8 x i32> %a to <8 x double>
  ret <8 x double> %b
}
define <8 x double> @sitof64_mask(<8 x double> %a, <8 x i32> %b, i8 %c) nounwind {
; KNL-LABEL: sitof64_mask:
; KNL:       ## BB#0:
; KNL-NEXT:    kmovw %edi, %k1
; KNL-NEXT:    vcvtdq2pd %ymm1, %zmm0 {%k1}
; KNL-NEXT:    retq
;
; SKX-LABEL: sitof64_mask:
; SKX:       ## BB#0:
; SKX-NEXT:    kmovb %edi, %k1
; SKX-NEXT:    vcvtdq2pd %ymm1, %zmm0 {%k1}
; SKX-NEXT:    retq
  %1 = bitcast i8 %c to <8 x i1>
  %2 = sitofp <8 x i32> %b to <8 x double>
  %3 = select <8 x i1> %1, <8 x double> %2, <8 x double> %a
  ret <8 x double> %3
}
define <8 x double> @sitof64_maskz(<8 x i32> %a, i8 %b) nounwind {
; KNL-LABEL: sitof64_maskz:
; KNL:       ## BB#0:
; KNL-NEXT:    kmovw %edi, %k1
; KNL-NEXT:    vcvtdq2pd %ymm0, %zmm0 {%k1} {z}
; KNL-NEXT:    retq
;
; SKX-LABEL: sitof64_maskz:
; SKX:       ## BB#0:
; SKX-NEXT:    kmovb %edi, %k1
; SKX-NEXT:    vcvtdq2pd %ymm0, %zmm0 {%k1} {z}
; SKX-NEXT:    retq
  %1 = bitcast i8 %b to <8 x i1>
  %2 = sitofp <8 x i32> %a to <8 x double>
  %3 = select <8 x i1> %1, <8 x double> %2, <8 x double> zeroinitializer
  ret <8 x double> %3
}

define <8 x i32> @fptosi01(<8 x double> %a) {
; ALL-LABEL: fptosi01:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttpd2dq %zmm0, %ymm0
; ALL-NEXT:    retq
  %b = fptosi <8 x double> %a to <8 x i32>
  ret <8 x i32> %b
}

define <4 x i32> @fptosi03(<4 x double> %a) {
; ALL-LABEL: fptosi03:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttpd2dq %ymm0, %xmm0
; ALL-NEXT:    retq
  %b = fptosi <4 x double> %a to <4 x i32>
  ret <4 x i32> %b
}

define <16 x float> @fptrunc00(<16 x double> %b) nounwind {
; KNL-LABEL: fptrunc00:
; KNL:       ## BB#0:
; KNL-NEXT:    vcvtpd2ps %zmm0, %ymm0
; KNL-NEXT:    vcvtpd2ps %zmm1, %ymm1
; KNL-NEXT:    vinsertf64x4 $1, %ymm1, %zmm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: fptrunc00:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtpd2ps %zmm0, %ymm0
; SKX-NEXT:    vcvtpd2ps %zmm1, %ymm1
; SKX-NEXT:    vinsertf32x8 $1, %ymm1, %zmm0, %zmm0
; SKX-NEXT:    retq
  %a = fptrunc <16 x double> %b to <16 x float>
  ret <16 x float> %a
}

define <4 x float> @fptrunc01(<4 x double> %b) {
; ALL-LABEL: fptrunc01:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtpd2ps %ymm0, %xmm0
; ALL-NEXT:    retq
  %a = fptrunc <4 x double> %b to <4 x float>
  ret <4 x float> %a
}

define <4 x float> @fptrunc02(<4 x double> %b, <4 x i1> %mask) {
; KNL-LABEL: fptrunc02:
; KNL:       ## BB#0:
; KNL-NEXT:    vpslld $31, %xmm1, %xmm1
; KNL-NEXT:    vpsrad $31, %xmm1, %xmm1
; KNL-NEXT:    vcvtpd2ps %ymm0, %xmm0
; KNL-NEXT:    vpand %xmm0, %xmm1, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: fptrunc02:
; SKX:       ## BB#0:
; SKX-NEXT:    vpslld $31, %xmm1, %xmm1
; SKX-NEXT:    vptestmd %xmm1, %xmm1, %k1
; SKX-NEXT:    vcvtpd2ps %ymm0, %xmm0 {%k1} {z}
; SKX-NEXT:    retq
  %a = fptrunc <4 x double> %b to <4 x float>
  %c = select <4 x i1>%mask, <4 x float>%a, <4 x float> zeroinitializer
  ret <4 x float> %c
}

define <8 x double> @fpext00(<8 x float> %b) nounwind {
; ALL-LABEL: fpext00:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtps2pd %ymm0, %zmm0
; ALL-NEXT:    retq
  %a = fpext <8 x float> %b to <8 x double>
  ret <8 x double> %a
}

define <4 x double> @fpext01(<4 x float> %b, <4 x double>%b1, <4 x double>%a1) {
; KNL-LABEL: fpext01:
; KNL:       ## BB#0:
; KNL-NEXT:    vcvtps2pd %xmm0, %ymm0
; KNL-NEXT:    vcmpltpd %ymm2, %ymm1, %ymm1
; KNL-NEXT:    vandpd %ymm0, %ymm1, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: fpext01:
; SKX:       ## BB#0:
; SKX-NEXT:    vcmpltpd %ymm2, %ymm1, %k1
; SKX-NEXT:    vcvtps2pd %xmm0, %ymm0 {%k1} {z}
; SKX-NEXT:    retq
  %a = fpext <4 x float> %b to <4 x double>
  %mask = fcmp ogt <4 x double>%a1, %b1
  %c = select <4 x i1>%mask,  <4 x double>%a, <4 x double>zeroinitializer
  ret <4 x double> %c
}

define double @funcA(i64* nocapture %e) {
; ALL-LABEL: funcA:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vcvtsi2sdq (%rdi), %xmm0, %xmm0
; ALL-NEXT:    retq
entry:
  %tmp1 = load i64, i64* %e, align 8
  %conv = sitofp i64 %tmp1 to double
  ret double %conv
}

define double @funcB(i32* %e) {
; ALL-LABEL: funcB:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vcvtsi2sdl (%rdi), %xmm0, %xmm0
; ALL-NEXT:    retq
entry:
  %tmp1 = load i32, i32* %e, align 4
  %conv = sitofp i32 %tmp1 to double
  ret double %conv
}

define float @funcC(i32* %e) {
; ALL-LABEL: funcC:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vcvtsi2ssl (%rdi), %xmm0, %xmm0
; ALL-NEXT:    retq
entry:
  %tmp1 = load i32, i32* %e, align 4
  %conv = sitofp i32 %tmp1 to float
  ret float %conv
}

define float @i64tof32(i64* %e) {
; ALL-LABEL: i64tof32:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vcvtsi2ssq (%rdi), %xmm0, %xmm0
; ALL-NEXT:    retq
entry:
  %tmp1 = load i64, i64* %e, align 8
  %conv = sitofp i64 %tmp1 to float
  ret float %conv
}

define void @fpext() {
; ALL-LABEL: fpext:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vmovss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; ALL-NEXT:    vcvtss2sd %xmm0, %xmm0, %xmm0
; ALL-NEXT:    vmovsd %xmm0, -{{[0-9]+}}(%rsp)
; ALL-NEXT:    retq
entry:
  %f = alloca float, align 4
  %d = alloca double, align 8
  %tmp = load float, float* %f, align 4
  %conv = fpext float %tmp to double
  store double %conv, double* %d, align 8
  ret void
}

define void @fpround_scalar() nounwind uwtable {
; ALL-LABEL: fpround_scalar:
; ALL:       ## BB#0: ## %entry
; ALL-NEXT:    vmovsd {{.*#+}} xmm0 = mem[0],zero
; ALL-NEXT:    vcvtsd2ss %xmm0, %xmm0, %xmm0
; ALL-NEXT:    vmovss %xmm0, -{{[0-9]+}}(%rsp)
; ALL-NEXT:    retq
entry:
  %f = alloca float, align 4
  %d = alloca double, align 8
  %tmp = load double, double* %d, align 8
  %conv = fptrunc double %tmp to float
  store float %conv, float* %f, align 4
  ret void
}

define double @long_to_double(i64 %x) {
; ALL-LABEL: long_to_double:
; ALL:       ## BB#0:
; ALL-NEXT:    vmovq %rdi, %xmm0
; ALL-NEXT:    retq
   %res = bitcast i64 %x to double
   ret double %res
}

define i64 @double_to_long(double %x) {
; ALL-LABEL: double_to_long:
; ALL:       ## BB#0:
; ALL-NEXT:    vmovq %xmm0, %rax
; ALL-NEXT:    retq
   %res = bitcast double %x to i64
   ret i64 %res
}

define float @int_to_float(i32 %x) {
; ALL-LABEL: int_to_float:
; ALL:       ## BB#0:
; ALL-NEXT:    vmovd %edi, %xmm0
; ALL-NEXT:    retq
   %res = bitcast i32 %x to float
   ret float %res
}

define i32 @float_to_int(float %x) {
; ALL-LABEL: float_to_int:
; ALL:       ## BB#0:
; ALL-NEXT:    vmovd %xmm0, %eax
; ALL-NEXT:    retq
   %res = bitcast float %x to i32
   ret i32 %res
}

define <16 x double> @uitof64(<16 x i32> %a) nounwind {
; KNL-LABEL: uitof64:
; KNL:       ## BB#0:
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm2
; KNL-NEXT:    vextracti64x4 $1, %zmm0, %ymm0
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm1
; KNL-NEXT:    vmovaps %zmm2, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof64:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtudq2pd %ymm0, %zmm2
; SKX-NEXT:    vextracti32x8 $1, %zmm0, %ymm0
; SKX-NEXT:    vcvtudq2pd %ymm0, %zmm1
; SKX-NEXT:    vmovaps %zmm2, %zmm0
; SKX-NEXT:    retq
  %b = uitofp <16 x i32> %a to <16 x double>
  ret <16 x double> %b
}
define <8 x double> @uitof64_mask(<8 x double> %a, <8 x i32> %b, i8 %c) nounwind {
; KNL-LABEL: uitof64_mask:
; KNL:       ## BB#0:
; KNL-NEXT:    kmovw %edi, %k1
; KNL-NEXT:    vcvtudq2pd %ymm1, %zmm0 {%k1}
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof64_mask:
; SKX:       ## BB#0:
; SKX-NEXT:    kmovb %edi, %k1
; SKX-NEXT:    vcvtudq2pd %ymm1, %zmm0 {%k1}
; SKX-NEXT:    retq
  %1 = bitcast i8 %c to <8 x i1>
  %2 = uitofp <8 x i32> %b to <8 x double>
  %3 = select <8 x i1> %1, <8 x double> %2, <8 x double> %a
  ret <8 x double> %3
}
define <8 x double> @uitof64_maskz(<8 x i32> %a, i8 %b) nounwind {
; KNL-LABEL: uitof64_maskz:
; KNL:       ## BB#0:
; KNL-NEXT:    kmovw %edi, %k1
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm0 {%k1} {z}
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof64_maskz:
; SKX:       ## BB#0:
; SKX-NEXT:    kmovb %edi, %k1
; SKX-NEXT:    vcvtudq2pd %ymm0, %zmm0 {%k1} {z}
; SKX-NEXT:    retq
  %1 = bitcast i8 %b to <8 x i1>
  %2 = uitofp <8 x i32> %a to <8 x double>
  %3 = select <8 x i1> %1, <8 x double> %2, <8 x double> zeroinitializer
  ret <8 x double> %3
}

define <4 x double> @uitof64_256(<4 x i32> %a) nounwind {
; KNL-LABEL: uitof64_256:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %YMM0<def>
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm0
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof64_256:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtudq2pd %xmm0, %ymm0
; SKX-NEXT:    retq
  %b = uitofp <4 x i32> %a to <4 x double>
  ret <4 x double> %b
}

define <16 x float> @uitof32(<16 x i32> %a) nounwind {
; ALL-LABEL: uitof32:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtudq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = uitofp <16 x i32> %a to <16 x float>
  ret <16 x float> %b
}

define <8 x float> @uitof32_256(<8 x i32> %a) nounwind {
; KNL-LABEL: uitof32_256:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vcvtudq2ps %zmm0, %zmm0
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof32_256:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtudq2ps %ymm0, %ymm0
; SKX-NEXT:    retq
  %b = uitofp <8 x i32> %a to <8 x float>
  ret <8 x float> %b
}

define <4 x float> @uitof32_128(<4 x i32> %a) nounwind {
; KNL-LABEL: uitof32_128:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %ZMM0<def>
; KNL-NEXT:    vcvtudq2ps %zmm0, %zmm0
; KNL-NEXT:    ## kill: %XMM0<def> %XMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: uitof32_128:
; SKX:       ## BB#0:
; SKX-NEXT:    vcvtudq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %b = uitofp <4 x i32> %a to <4 x float>
  ret <4 x float> %b
}

define i32 @fptosi02(float %a) nounwind {
; ALL-LABEL: fptosi02:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttss2si %xmm0, %eax
; ALL-NEXT:    retq
  %b = fptosi float %a to i32
  ret i32 %b
}

define i32 @fptoui02(float %a) nounwind {
; ALL-LABEL: fptoui02:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvttss2usi %xmm0, %eax
; ALL-NEXT:    retq
  %b = fptoui float %a to i32
  ret i32 %b
}

define float @uitofp02(i32 %a) nounwind {
; ALL-LABEL: uitofp02:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtusi2ssl %edi, %xmm0, %xmm0
; ALL-NEXT:    retq
  %b = uitofp i32 %a to float
  ret float %b
}

define double @uitofp03(i32 %a) nounwind {
; ALL-LABEL: uitofp03:
; ALL:       ## BB#0:
; ALL-NEXT:    vcvtusi2sdl %edi, %xmm0, %xmm0
; ALL-NEXT:    retq
  %b = uitofp i32 %a to double
  ret double %b
}

define <16 x float> @sitofp_16i1_float(<16 x i32> %a) {
; KNL-LABEL: sitofp_16i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; KNL-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; KNL-NEXT:    vpternlogd $255, %zmm0, %zmm0, %zmm0
; KNL-NEXT:    vmovdqa32 %zmm0, %zmm0 {%k1} {z}
; KNL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_16i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; SKX-NEXT:    vpcmpgtd %zmm0, %zmm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %zmm0
; SKX-NEXT:    vcvtdq2ps %zmm0, %zmm0
; SKX-NEXT:    retq
  %mask = icmp slt <16 x i32> %a, zeroinitializer
  %1 = sitofp <16 x i1> %mask to <16 x float>
  ret <16 x float> %1
}

define <16 x float> @sitofp_16i8_float(<16 x i8> %a) {
; ALL-LABEL: sitofp_16i8_float:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovsxbd %xmm0, %zmm0
; ALL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %1 = sitofp <16 x i8> %a to <16 x float>
  ret <16 x float> %1
}

define <16 x float> @sitofp_16i16_float(<16 x i16> %a) {
; ALL-LABEL: sitofp_16i16_float:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovsxwd %ymm0, %zmm0
; ALL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %1 = sitofp <16 x i16> %a to <16 x float>
  ret <16 x float> %1
}

define <8 x double> @sitofp_8i16_double(<8 x i16> %a) {
; ALL-LABEL: sitofp_8i16_double:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovsxwd %xmm0, %ymm0
; ALL-NEXT:    vcvtdq2pd %ymm0, %zmm0
; ALL-NEXT:    retq
  %1 = sitofp <8 x i16> %a to <8 x double>
  ret <8 x double> %1
}

define <8 x double> @sitofp_8i8_double(<8 x i8> %a) {
; ALL-LABEL: sitofp_8i8_double:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovzxwd {{.*#+}} ymm0 = xmm0[0],zero,xmm0[1],zero,xmm0[2],zero,xmm0[3],zero,xmm0[4],zero,xmm0[5],zero,xmm0[6],zero,xmm0[7],zero
; ALL-NEXT:    vpslld $24, %ymm0, %ymm0
; ALL-NEXT:    vpsrad $24, %ymm0, %ymm0
; ALL-NEXT:    vcvtdq2pd %ymm0, %zmm0
; ALL-NEXT:    retq
  %1 = sitofp <8 x i8> %a to <8 x double>
  ret <8 x double> %1
}

define <16 x double> @sitofp_16i1_double(<16 x double> %a) {
; KNL-LABEL: sitofp_16i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxord %zmm2, %zmm2, %zmm2
; KNL-NEXT:    vcmpltpd %zmm1, %zmm2, %k1
; KNL-NEXT:    vcmpltpd %zmm0, %zmm2, %k2
; KNL-NEXT:    vpternlogd $255, %zmm1, %zmm1, %zmm1
; KNL-NEXT:    vmovdqa64 %zmm1, %zmm0 {%k2} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtdq2pd %ymm0, %zmm0
; KNL-NEXT:    vmovdqa64 %zmm1, %zmm1 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm1, %ymm1
; KNL-NEXT:    vcvtdq2pd %ymm1, %zmm1
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_16i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorpd %zmm2, %zmm2, %zmm2
; SKX-NEXT:    vcmpltpd %zmm1, %zmm2, %k0
; SKX-NEXT:    vcmpltpd %zmm0, %zmm2, %k1
; SKX-NEXT:    vpmovm2d %k1, %ymm0
; SKX-NEXT:    vcvtdq2pd %ymm0, %zmm0
; SKX-NEXT:    vpmovm2d %k0, %ymm1
; SKX-NEXT:    vcvtdq2pd %ymm1, %zmm1
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <16 x double> %a, zeroinitializer
  %1 = sitofp <16 x i1> %cmpres to <16 x double>
  ret <16 x double> %1
}

define <8 x double> @sitofp_8i1_double(<8 x double> %a) {
; KNL-LABEL: sitofp_8i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; KNL-NEXT:    vcmpltpd %zmm0, %zmm1, %k1
; KNL-NEXT:    vpternlogd $255, %zmm0, %zmm0, %zmm0
; KNL-NEXT:    vmovdqa64 %zmm0, %zmm0 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtdq2pd %ymm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_8i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorpd %zmm1, %zmm1, %zmm1
; SKX-NEXT:    vcmpltpd %zmm0, %zmm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %ymm0
; SKX-NEXT:    vcvtdq2pd %ymm0, %zmm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <8 x double> %a, zeroinitializer
  %1 = sitofp <8 x i1> %cmpres to <8 x double>
  ret <8 x double> %1
}

define <8 x float> @sitofp_8i1_float(<8 x float> %a) {
; KNL-LABEL: sitofp_8i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vxorps %ymm1, %ymm1, %ymm1
; KNL-NEXT:    vcmpltps %zmm0, %zmm1, %k1
; KNL-NEXT:    vpternlogd $255, %zmm0, %zmm0, %zmm0
; KNL-NEXT:    vmovdqa64 %zmm0, %zmm0 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtdq2ps %ymm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_8i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorps %ymm1, %ymm1, %ymm1
; SKX-NEXT:    vcmpltps %ymm0, %ymm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %ymm0
; SKX-NEXT:    vcvtdq2ps %ymm0, %ymm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <8 x float> %a, zeroinitializer
  %1 = sitofp <8 x i1> %cmpres to <8 x float>
  ret <8 x float> %1
}

define <4 x float> @sitofp_4i1_float(<4 x float> %a) {
; KNL-LABEL: sitofp_4i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    vxorps %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vcmpltps %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vcvtdq2ps %xmm0, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_4i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorps %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vcmpltps %xmm0, %xmm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %xmm0
; SKX-NEXT:    vcvtdq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <4 x float> %a, zeroinitializer
  %1 = sitofp <4 x i1> %cmpres to <4 x float>
  ret <4 x float> %1
}

define <4 x double> @sitofp_4i1_double(<4 x double> %a) {
; KNL-LABEL: sitofp_4i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vxorpd %ymm1, %ymm1, %ymm1
; KNL-NEXT:    vcmpltpd %ymm0, %ymm1, %ymm0
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtdq2pd %xmm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_4i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorpd %ymm1, %ymm1, %ymm1
; SKX-NEXT:    vcmpltpd %ymm0, %ymm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %xmm0
; SKX-NEXT:    vcvtdq2pd %xmm0, %ymm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <4 x double> %a, zeroinitializer
  %1 = sitofp <4 x i1> %cmpres to <4 x double>
  ret <4 x double> %1
}

define <2 x float> @sitofp_2i1_float(<2 x float> %a) {
; KNL-LABEL: sitofp_2i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    vxorps %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vcmpltps %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm0[0,1],zero,xmm0[1]
; KNL-NEXT:    vcvtdq2ps %xmm0, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_2i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorps %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vcmpltps %xmm0, %xmm1, %k0
; SKX-NEXT:    vpmovm2d %k0, %xmm0
; SKX-NEXT:    vcvtdq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <2 x float> %a, zeroinitializer
  %1 = sitofp <2 x i1> %cmpres to <2 x float>
  ret <2 x float> %1
}

define <2 x double> @sitofp_2i1_double(<2 x double> %a) {
; KNL-LABEL: sitofp_2i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vxorpd %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vcmpltpd %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vpermilps {{.*#+}} xmm0 = xmm0[0,2,2,3]
; KNL-NEXT:    vcvtdq2pd %xmm0, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: sitofp_2i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vxorpd %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vcmpltpd %xmm0, %xmm1, %k0
; SKX-NEXT:    vpmovm2q %k0, %xmm0
; SKX-NEXT:    vcvtqq2pd %xmm0, %xmm0
; SKX-NEXT:    retq
  %cmpres = fcmp ogt <2 x double> %a, zeroinitializer
  %1 = sitofp <2 x i1> %cmpres to <2 x double>
  ret <2 x double> %1
}

define <16 x float> @uitofp_16i8(<16 x i8>%a) {
; ALL-LABEL: uitofp_16i8:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovzxbd {{.*#+}} zmm0 = xmm0[0],zero,zero,zero,xmm0[1],zero,zero,zero,xmm0[2],zero,zero,zero,xmm0[3],zero,zero,zero,xmm0[4],zero,zero,zero,xmm0[5],zero,zero,zero,xmm0[6],zero,zero,zero,xmm0[7],zero,zero,zero,xmm0[8],zero,zero,zero,xmm0[9],zero,zero,zero,xmm0[10],zero,zero,zero,xmm0[11],zero,zero,zero,xmm0[12],zero,zero,zero,xmm0[13],zero,zero,zero,xmm0[14],zero,zero,zero,xmm0[15],zero,zero,zero
; ALL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = uitofp <16 x i8> %a to <16 x float>
  ret <16 x float>%b
}

define <16 x float> @uitofp_16i16(<16 x i16>%a) {
; ALL-LABEL: uitofp_16i16:
; ALL:       ## BB#0:
; ALL-NEXT:    vpmovzxwd {{.*#+}} zmm0 = ymm0[0],zero,ymm0[1],zero,ymm0[2],zero,ymm0[3],zero,ymm0[4],zero,ymm0[5],zero,ymm0[6],zero,ymm0[7],zero,ymm0[8],zero,ymm0[9],zero,ymm0[10],zero,ymm0[11],zero,ymm0[12],zero,ymm0[13],zero,ymm0[14],zero,ymm0[15],zero
; ALL-NEXT:    vcvtdq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %b = uitofp <16 x i16> %a to <16 x float>
  ret <16 x float>%b
}

define <16 x float> @uitofp_16i1_float(<16 x i32> %a) {
; ALL-LABEL: uitofp_16i1_float:
; ALL:       ## BB#0:
; ALL-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; ALL-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; ALL-NEXT:    vpbroadcastd {{.*}}(%rip), %zmm0 {%k1} {z}
; ALL-NEXT:    vcvtudq2ps %zmm0, %zmm0
; ALL-NEXT:    retq
  %mask = icmp slt <16 x i32> %a, zeroinitializer
  %1 = uitofp <16 x i1> %mask to <16 x float>
  ret <16 x float> %1
}

define <16 x double> @uitofp_16i1_double(<16 x i32> %a) {
; KNL-LABEL: uitofp_16i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; KNL-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; KNL-NEXT:    movq {{.*}}(%rip), %rax
; KNL-NEXT:    vpbroadcastq %rax, %zmm0 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm0
; KNL-NEXT:    kshiftrw $8, %k1, %k1
; KNL-NEXT:    vpbroadcastq %rax, %zmm1 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm1, %ymm1
; KNL-NEXT:    vcvtudq2pd %ymm1, %zmm1
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_16i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %zmm1, %zmm1, %zmm1
; SKX-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; SKX-NEXT:    movl {{.*}}(%rip), %eax
; SKX-NEXT:    vpbroadcastd %eax, %ymm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2pd %ymm0, %zmm0
; SKX-NEXT:    kshiftrw $8, %k1, %k1
; SKX-NEXT:    vpbroadcastd %eax, %ymm1 {%k1} {z}
; SKX-NEXT:    vcvtudq2pd %ymm1, %zmm1
; SKX-NEXT:    retq
  %mask = icmp slt <16 x i32> %a, zeroinitializer
  %1 = uitofp <16 x i1> %mask to <16 x double>
  ret <16 x double> %1
}

define <8 x float> @uitofp_8i1_float(<8 x i32> %a) {
; KNL-LABEL: uitofp_8i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vpxor %ymm1, %ymm1, %ymm1
; KNL-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; KNL-NEXT:    vpbroadcastq {{.*}}(%rip), %zmm0 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtudq2ps %zmm0, %zmm0
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<kill>
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_8i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %ymm1, %ymm1, %ymm1
; SKX-NEXT:    vpcmpgtd %ymm0, %ymm1, %k1
; SKX-NEXT:    vpbroadcastd {{.*}}(%rip), %ymm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2ps %ymm0, %ymm0
; SKX-NEXT:    retq
  %mask = icmp slt <8 x i32> %a, zeroinitializer
  %1 = uitofp <8 x i1> %mask to <8 x float>
  ret <8 x float> %1
}

define <8 x double> @uitofp_8i1_double(<8 x i32> %a) {
; KNL-LABEL: uitofp_8i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    ## kill: %YMM0<def> %YMM0<kill> %ZMM0<def>
; KNL-NEXT:    vpxor %ymm1, %ymm1, %ymm1
; KNL-NEXT:    vpcmpgtd %zmm0, %zmm1, %k1
; KNL-NEXT:    vpbroadcastq {{.*}}(%rip), %zmm0 {%k1} {z}
; KNL-NEXT:    vpmovqd %zmm0, %ymm0
; KNL-NEXT:    vcvtudq2pd %ymm0, %zmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_8i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %ymm1, %ymm1, %ymm1
; SKX-NEXT:    vpcmpgtd %ymm0, %ymm1, %k1
; SKX-NEXT:    vpbroadcastd {{.*}}(%rip), %ymm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2pd %ymm0, %zmm0
; SKX-NEXT:    retq
  %mask = icmp slt <8 x i32> %a, zeroinitializer
  %1 = uitofp <8 x i1> %mask to <8 x double>
  ret <8 x double> %1
}

define <4 x float> @uitofp_4i1_float(<4 x i32> %a) {
; KNL-LABEL: uitofp_4i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxor %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vpcmpgtd %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vpbroadcastd {{.*}}(%rip), %xmm1
; KNL-NEXT:    vpand %xmm1, %xmm0, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_4i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vpcmpgtd %xmm0, %xmm1, %k1
; SKX-NEXT:    vpbroadcastd {{.*}}(%rip), %xmm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %mask = icmp slt <4 x i32> %a, zeroinitializer
  %1 = uitofp <4 x i1> %mask to <4 x float>
  ret <4 x float> %1
}

define <4 x double> @uitofp_4i1_double(<4 x i32> %a) {
; KNL-LABEL: uitofp_4i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxor %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vpcmpgtd %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vpsrld $31, %xmm0, %xmm0
; KNL-NEXT:    vcvtdq2pd %xmm0, %ymm0
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_4i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vpcmpgtd %xmm0, %xmm1, %k1
; SKX-NEXT:    vpbroadcastd {{.*}}(%rip), %xmm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2pd %xmm0, %ymm0
; SKX-NEXT:    retq
  %mask = icmp slt <4 x i32> %a, zeroinitializer
  %1 = uitofp <4 x i1> %mask to <4 x double>
  ret <4 x double> %1
}

define <2 x float> @uitofp_2i1_float(<2 x i32> %a) {
; KNL-LABEL: uitofp_2i1_float:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxor %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vpblendd {{.*#+}} xmm0 = xmm0[0],xmm1[1],xmm0[2],xmm1[3]
; KNL-NEXT:    vmovdqa {{.*#+}} xmm1 = [9223372036854775808,9223372036854775808]
; KNL-NEXT:    vpxor %xmm1, %xmm0, %xmm0
; KNL-NEXT:    vpcmpgtq %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vpextrq $1, %xmm0, %rax
; KNL-NEXT:    andl $1, %eax
; KNL-NEXT:    vcvtsi2ssl %eax, %xmm2, %xmm1
; KNL-NEXT:    vmovq %xmm0, %rax
; KNL-NEXT:    andl $1, %eax
; KNL-NEXT:    vcvtsi2ssl %eax, %xmm2, %xmm0
; KNL-NEXT:    vinsertps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[2,3]
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_2i1_float:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vpblendd {{.*#+}} xmm0 = xmm0[0],xmm1[1],xmm0[2],xmm1[3]
; SKX-NEXT:    vpcmpltuq %xmm1, %xmm0, %k1
; SKX-NEXT:    vpbroadcastd {{.*}}(%rip), %xmm0 {%k1} {z}
; SKX-NEXT:    vcvtudq2ps %xmm0, %xmm0
; SKX-NEXT:    retq
  %mask = icmp ult <2 x i32> %a, zeroinitializer
  %1 = uitofp <2 x i1> %mask to <2 x float>
  ret <2 x float> %1
}

define <2 x double> @uitofp_2i1_double(<2 x i32> %a) {
; KNL-LABEL: uitofp_2i1_double:
; KNL:       ## BB#0:
; KNL-NEXT:    vpxor %xmm1, %xmm1, %xmm1
; KNL-NEXT:    vpblendd {{.*#+}} xmm0 = xmm0[0],xmm1[1],xmm0[2],xmm1[3]
; KNL-NEXT:    vmovdqa {{.*#+}} xmm1 = [9223372036854775808,9223372036854775808]
; KNL-NEXT:    vpxor %xmm1, %xmm0, %xmm0
; KNL-NEXT:    vpcmpgtq %xmm0, %xmm1, %xmm0
; KNL-NEXT:    vpand {{.*}}(%rip), %xmm0, %xmm0
; KNL-NEXT:    retq
;
; SKX-LABEL: uitofp_2i1_double:
; SKX:       ## BB#0:
; SKX-NEXT:    vpxord %xmm1, %xmm1, %xmm1
; SKX-NEXT:    vpblendd {{.*#+}} xmm0 = xmm0[0],xmm1[1],xmm0[2],xmm1[3]
; SKX-NEXT:    vpcmpltuq %xmm1, %xmm0, %k1
; SKX-NEXT:    vmovdqa64 {{.*}}(%rip), %xmm0 {%k1} {z}
; SKX-NEXT:    vcvtuqq2pd %xmm0, %xmm0
; SKX-NEXT:    retq
  %mask = icmp ult <2 x i32> %a, zeroinitializer
  %1 = uitofp <2 x i1> %mask to <2 x double>
  ret <2 x double> %1
}
