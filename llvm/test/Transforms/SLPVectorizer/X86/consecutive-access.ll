; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -basicaa -slp-vectorizer -S | FileCheck %s
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.9.0"

@A = common global [2000 x double] zeroinitializer, align 16
@B = common global [2000 x double] zeroinitializer, align 16
@C = common global [2000 x float] zeroinitializer, align 16
@D = common global [2000 x float] zeroinitializer, align 16

; Currently SCEV isn't smart enough to figure out that accesses
; A[3*i], A[3*i+1] and A[3*i+2] are consecutive, but in future
; that would hopefully be fixed. For now, check that this isn't
; vectorized.
; Function Attrs: nounwind ssp uwtable
define void @foo_3double(i32 %u) #0 {
; CHECK-LABEL: @foo_3double(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[U_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 [[U:%.*]], i32* [[U_ADDR]], align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul nsw i32 [[U]], 3
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[MUL]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[TMP0:%.*]] = load double, double* [[ARRAYIDX]], align 8
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[TMP1:%.*]] = load double, double* [[ARRAYIDX4]], align 8
; CHECK-NEXT:    [[ADD5:%.*]] = fadd double [[TMP0]], [[TMP1]]
; CHECK-NEXT:    store double [[ADD5]], double* [[ARRAYIDX]], align 8
; CHECK-NEXT:    [[ADD11:%.*]] = add nsw i32 [[MUL]], 1
; CHECK-NEXT:    [[IDXPROM12:%.*]] = sext i32 [[ADD11]] to i64
; CHECK-NEXT:    [[ARRAYIDX13:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP2:%.*]] = load double, double* [[ARRAYIDX13]], align 8
; CHECK-NEXT:    [[ARRAYIDX17:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP3:%.*]] = load double, double* [[ARRAYIDX17]], align 8
; CHECK-NEXT:    [[ADD18:%.*]] = fadd double [[TMP2]], [[TMP3]]
; CHECK-NEXT:    store double [[ADD18]], double* [[ARRAYIDX13]], align 8
; CHECK-NEXT:    [[ADD24:%.*]] = add nsw i32 [[MUL]], 2
; CHECK-NEXT:    [[IDXPROM25:%.*]] = sext i32 [[ADD24]] to i64
; CHECK-NEXT:    [[ARRAYIDX26:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM25]]
; CHECK-NEXT:    [[TMP4:%.*]] = load double, double* [[ARRAYIDX26]], align 8
; CHECK-NEXT:    [[ARRAYIDX30:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM25]]
; CHECK-NEXT:    [[TMP5:%.*]] = load double, double* [[ARRAYIDX30]], align 8
; CHECK-NEXT:    [[ADD31:%.*]] = fadd double [[TMP4]], [[TMP5]]
; CHECK-NEXT:    store double [[ADD31]], double* [[ARRAYIDX26]], align 8
; CHECK-NEXT:    ret void
;
entry:
  %u.addr = alloca i32, align 4
  store i32 %u, i32* %u.addr, align 4
  %mul = mul nsw i32 %u, 3
  %idxprom = sext i32 %mul to i64
  %arrayidx = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom
  %0 = load double, double* %arrayidx, align 8
  %arrayidx4 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom
  %1 = load double, double* %arrayidx4, align 8
  %add5 = fadd double %0, %1
  store double %add5, double* %arrayidx, align 8
  %add11 = add nsw i32 %mul, 1
  %idxprom12 = sext i32 %add11 to i64
  %arrayidx13 = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom12
  %2 = load double, double* %arrayidx13, align 8
  %arrayidx17 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom12
  %3 = load double, double* %arrayidx17, align 8
  %add18 = fadd double %2, %3
  store double %add18, double* %arrayidx13, align 8
  %add24 = add nsw i32 %mul, 2
  %idxprom25 = sext i32 %add24 to i64
  %arrayidx26 = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom25
  %4 = load double, double* %arrayidx26, align 8
  %arrayidx30 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom25
  %5 = load double, double* %arrayidx30, align 8
  %add31 = fadd double %4, %5
  store double %add31, double* %arrayidx26, align 8
  ret void
}

; SCEV should be able to tell that accesses A[C1 + C2*i], A[C1 + C2*i], ...
; A[C1 + C2*i] are consecutive, if C2 is a power of 2, and C2 > C1 > 0.
; Thus, the following code should be vectorized.
; Function Attrs: nounwind ssp uwtable
define void @foo_2double(i32 %u) #0 {
; CHECK-LABEL: @foo_2double(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[U_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 [[U:%.*]], i32* [[U_ADDR]], align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul nsw i32 [[U]], 2
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[MUL]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD11:%.*]] = add nsw i32 [[MUL]], 1
; CHECK-NEXT:    [[IDXPROM12:%.*]] = sext i32 [[ADD11]] to i64
; CHECK-NEXT:    [[ARRAYIDX13:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP1:%.*]] = load <2 x double>, <2 x double>* [[TMP0]], align 8
; CHECK-NEXT:    [[ARRAYIDX17:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* [[ARRAYIDX4]] to <2 x double>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <2 x double>, <2 x double>* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = fadd <2 x double> [[TMP1]], [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    store <2 x double> [[TMP4]], <2 x double>* [[TMP5]], align 8
; CHECK-NEXT:    ret void
;
entry:
  %u.addr = alloca i32, align 4
  store i32 %u, i32* %u.addr, align 4
  %mul = mul nsw i32 %u, 2
  %idxprom = sext i32 %mul to i64
  %arrayidx = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom
  %0 = load double, double* %arrayidx, align 8
  %arrayidx4 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom
  %1 = load double, double* %arrayidx4, align 8
  %add5 = fadd double %0, %1
  store double %add5, double* %arrayidx, align 8
  %add11 = add nsw i32 %mul, 1
  %idxprom12 = sext i32 %add11 to i64
  %arrayidx13 = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom12
  %2 = load double, double* %arrayidx13, align 8
  %arrayidx17 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom12
  %3 = load double, double* %arrayidx17, align 8
  %add18 = fadd double %2, %3
  store double %add18, double* %arrayidx13, align 8
  ret void
}

; Similar to the previous test, but with different datatype.
; Function Attrs: nounwind ssp uwtable
define void @foo_4float(i32 %u) #0 {
; CHECK-LABEL: @foo_4float(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[U_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 [[U:%.*]], i32* [[U_ADDR]], align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul nsw i32 [[U]], 4
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[MUL]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD11:%.*]] = add nsw i32 [[MUL]], 1
; CHECK-NEXT:    [[IDXPROM12:%.*]] = sext i32 [[ADD11]] to i64
; CHECK-NEXT:    [[ARRAYIDX13:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[ARRAYIDX17:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[ADD24:%.*]] = add nsw i32 [[MUL]], 2
; CHECK-NEXT:    [[IDXPROM25:%.*]] = sext i32 [[ADD24]] to i64
; CHECK-NEXT:    [[ARRAYIDX26:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 [[IDXPROM25]]
; CHECK-NEXT:    [[ARRAYIDX30:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 [[IDXPROM25]]
; CHECK-NEXT:    [[ADD37:%.*]] = add nsw i32 [[MUL]], 3
; CHECK-NEXT:    [[IDXPROM38:%.*]] = sext i32 [[ADD37]] to i64
; CHECK-NEXT:    [[ARRAYIDX39:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 [[IDXPROM38]]
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast float* [[ARRAYIDX]] to <4 x float>*
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x float>, <4 x float>* [[TMP0]], align 4
; CHECK-NEXT:    [[ARRAYIDX43:%.*]] = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 [[IDXPROM38]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast float* [[ARRAYIDX4]] to <4 x float>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <4 x float>, <4 x float>* [[TMP2]], align 4
; CHECK-NEXT:    [[TMP4:%.*]] = fadd <4 x float> [[TMP1]], [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast float* [[ARRAYIDX]] to <4 x float>*
; CHECK-NEXT:    store <4 x float> [[TMP4]], <4 x float>* [[TMP5]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %u.addr = alloca i32, align 4
  store i32 %u, i32* %u.addr, align 4
  %mul = mul nsw i32 %u, 4
  %idxprom = sext i32 %mul to i64
  %arrayidx = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 %idxprom
  %0 = load float, float* %arrayidx, align 4
  %arrayidx4 = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 %idxprom
  %1 = load float, float* %arrayidx4, align 4
  %add5 = fadd float %0, %1
  store float %add5, float* %arrayidx, align 4
  %add11 = add nsw i32 %mul, 1
  %idxprom12 = sext i32 %add11 to i64
  %arrayidx13 = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 %idxprom12
  %2 = load float, float* %arrayidx13, align 4
  %arrayidx17 = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 %idxprom12
  %3 = load float, float* %arrayidx17, align 4
  %add18 = fadd float %2, %3
  store float %add18, float* %arrayidx13, align 4
  %add24 = add nsw i32 %mul, 2
  %idxprom25 = sext i32 %add24 to i64
  %arrayidx26 = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 %idxprom25
  %4 = load float, float* %arrayidx26, align 4
  %arrayidx30 = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 %idxprom25
  %5 = load float, float* %arrayidx30, align 4
  %add31 = fadd float %4, %5
  store float %add31, float* %arrayidx26, align 4
  %add37 = add nsw i32 %mul, 3
  %idxprom38 = sext i32 %add37 to i64
  %arrayidx39 = getelementptr inbounds [2000 x float], [2000 x float]* @C, i32 0, i64 %idxprom38
  %6 = load float, float* %arrayidx39, align 4
  %arrayidx43 = getelementptr inbounds [2000 x float], [2000 x float]* @D, i32 0, i64 %idxprom38
  %7 = load float, float* %arrayidx43, align 4
  %add44 = fadd float %6, %7
  store float %add44, float* %arrayidx39, align 4
  ret void
}

; Similar to the previous tests, but now we are dealing with AddRec SCEV.
; Function Attrs: nounwind ssp uwtable
define i32 @foo_loop(double* %A, i32 %n) #0 {
; CHECK-LABEL: @foo_loop(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_ADDR:%.*]] = alloca double*, align 8
; CHECK-NEXT:    [[N_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[SUM:%.*]] = alloca double, align 8
; CHECK-NEXT:    [[I:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store double* [[A:%.*]], double** [[A_ADDR]], align 8
; CHECK-NEXT:    store i32 [[N:%.*]], i32* [[N_ADDR]], align 4
; CHECK-NEXT:    store double 0.000000e+00, double* [[SUM]], align 8
; CHECK-NEXT:    store i32 0, i32* [[I]], align 4
; CHECK-NEXT:    [[CMP1:%.*]] = icmp slt i32 0, [[N]]
; CHECK-NEXT:    br i1 [[CMP1]], label [[FOR_BODY_LR_PH:%.*]], label [[FOR_END:%.*]]
; CHECK:       for.body.lr.ph:
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i32 [ 0, [[FOR_BODY_LR_PH]] ], [ [[INC:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = phi double [ 0.000000e+00, [[FOR_BODY_LR_PH]] ], [ [[ADD7:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[MUL:%.*]] = mul nsw i32 [[TMP0]], 2
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[MUL]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD:%.*]] = add nsw i32 [[MUL]], 1
; CHECK-NEXT:    [[IDXPROM3:%.*]] = sext i32 [[ADD]] to i64
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IDXPROM3]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <2 x double>, <2 x double>* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = fmul <2 x double> <double 7.000000e+00, double 7.000000e+00>, [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = extractelement <2 x double> [[TMP4]], i32 0
; CHECK-NEXT:    [[TMP6:%.*]] = extractelement <2 x double> [[TMP4]], i32 1
; CHECK-NEXT:    [[ADD6:%.*]] = fadd double [[TMP5]], [[TMP6]]
; CHECK-NEXT:    [[ADD7]] = fadd double [[TMP1]], [[ADD6]]
; CHECK-NEXT:    store double [[ADD7]], double* [[SUM]], align 8
; CHECK-NEXT:    [[INC]] = add nsw i32 [[TMP0]], 1
; CHECK-NEXT:    store i32 [[INC]], i32* [[I]], align 4
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i32 [[INC]], [[N]]
; CHECK-NEXT:    br i1 [[CMP]], label [[FOR_BODY]], label [[FOR_COND_FOR_END_CRIT_EDGE:%.*]]
; CHECK:       for.cond.for.end_crit_edge:
; CHECK-NEXT:    [[SPLIT:%.*]] = phi double [ [[ADD7]], [[FOR_BODY]] ]
; CHECK-NEXT:    br label [[FOR_END]]
; CHECK:       for.end:
; CHECK-NEXT:    [[DOTLCSSA:%.*]] = phi double [ [[SPLIT]], [[FOR_COND_FOR_END_CRIT_EDGE]] ], [ 0.000000e+00, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[CONV:%.*]] = fptosi double [[DOTLCSSA]] to i32
; CHECK-NEXT:    ret i32 [[CONV]]
;
entry:
  %A.addr = alloca double*, align 8
  %n.addr = alloca i32, align 4
  %sum = alloca double, align 8
  %i = alloca i32, align 4
  store double* %A, double** %A.addr, align 8
  store i32 %n, i32* %n.addr, align 4
  store double 0.000000e+00, double* %sum, align 8
  store i32 0, i32* %i, align 4
  %cmp1 = icmp slt i32 0, %n
  br i1 %cmp1, label %for.body.lr.ph, label %for.end

for.body.lr.ph:                                   ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.lr.ph, %for.body
  %0 = phi i32 [ 0, %for.body.lr.ph ], [ %inc, %for.body ]
  %1 = phi double [ 0.000000e+00, %for.body.lr.ph ], [ %add7, %for.body ]
  %mul = mul nsw i32 %0, 2
  %idxprom = sext i32 %mul to i64
  %arrayidx = getelementptr inbounds double, double* %A, i64 %idxprom
  %2 = load double, double* %arrayidx, align 8
  %mul1 = fmul double 7.000000e+00, %2
  %add = add nsw i32 %mul, 1
  %idxprom3 = sext i32 %add to i64
  %arrayidx4 = getelementptr inbounds double, double* %A, i64 %idxprom3
  %3 = load double, double* %arrayidx4, align 8
  %mul5 = fmul double 7.000000e+00, %3
  %add6 = fadd double %mul1, %mul5
  %add7 = fadd double %1, %add6
  store double %add7, double* %sum, align 8
  %inc = add nsw i32 %0, 1
  store i32 %inc, i32* %i, align 4
  %cmp = icmp slt i32 %inc, %n
  br i1 %cmp, label %for.body, label %for.cond.for.end_crit_edge

for.cond.for.end_crit_edge:                       ; preds = %for.body
  %split = phi double [ %add7, %for.body ]
  br label %for.end

for.end:                                          ; preds = %for.cond.for.end_crit_edge, %entry
  %.lcssa = phi double [ %split, %for.cond.for.end_crit_edge ], [ 0.000000e+00, %entry ]
  %conv = fptosi double %.lcssa to i32
  ret i32 %conv
}

; Similar to foo_2double but with a non-power-of-2 factor and potential
; wrapping (both indices wrap or both don't in the same time)
; Function Attrs: nounwind ssp uwtable
define void @foo_2double_non_power_of_2(i32 %u) #0 {
; CHECK-LABEL: @foo_2double_non_power_of_2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[U_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 [[U:%.*]], i32* [[U_ADDR]], align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul i32 [[U]], 6
; CHECK-NEXT:    [[ADD6:%.*]] = add i32 [[MUL]], 6
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[ADD6]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD7:%.*]] = add i32 [[MUL]], 7
; CHECK-NEXT:    [[IDXPROM12:%.*]] = sext i32 [[ADD7]] to i64
; CHECK-NEXT:    [[ARRAYIDX13:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP1:%.*]] = load <2 x double>, <2 x double>* [[TMP0]], align 8
; CHECK-NEXT:    [[ARRAYIDX17:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* [[ARRAYIDX4]] to <2 x double>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <2 x double>, <2 x double>* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = fadd <2 x double> [[TMP1]], [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    store <2 x double> [[TMP4]], <2 x double>* [[TMP5]], align 8
; CHECK-NEXT:    ret void
;
entry:
  %u.addr = alloca i32, align 4
  store i32 %u, i32* %u.addr, align 4
  %mul = mul i32 %u, 6
  %add6 = add i32 %mul, 6
  %idxprom = sext i32 %add6 to i64
  %arrayidx = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom
  %0 = load double, double* %arrayidx, align 8
  %arrayidx4 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom
  %1 = load double, double* %arrayidx4, align 8
  %add5 = fadd double %0, %1
  store double %add5, double* %arrayidx, align 8
  %add7 = add i32 %mul, 7
  %idxprom12 = sext i32 %add7 to i64
  %arrayidx13 = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom12
  %2 = load double, double* %arrayidx13, align 8
  %arrayidx17 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom12
  %3 = load double, double* %arrayidx17, align 8
  %add18 = fadd double %2, %3
  store double %add18, double* %arrayidx13, align 8
  ret void
}

; Similar to foo_2double_non_power_of_2 but with zext's instead of sext's
; Function Attrs: nounwind ssp uwtable
define void @foo_2double_non_power_of_2_zext(i32 %u) #0 {
; CHECK-LABEL: @foo_2double_non_power_of_2_zext(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[U_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 [[U:%.*]], i32* [[U_ADDR]], align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul i32 [[U]], 6
; CHECK-NEXT:    [[ADD6:%.*]] = add i32 [[MUL]], 6
; CHECK-NEXT:    [[IDXPROM:%.*]] = zext i32 [[ADD6]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD7:%.*]] = add i32 [[MUL]], 7
; CHECK-NEXT:    [[IDXPROM12:%.*]] = zext i32 [[ADD7]] to i64
; CHECK-NEXT:    [[ARRAYIDX13:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP1:%.*]] = load <2 x double>, <2 x double>* [[TMP0]], align 8
; CHECK-NEXT:    [[ARRAYIDX17:%.*]] = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 [[IDXPROM12]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* [[ARRAYIDX4]] to <2 x double>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <2 x double>, <2 x double>* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = fadd <2 x double> [[TMP1]], [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    store <2 x double> [[TMP4]], <2 x double>* [[TMP5]], align 8
; CHECK-NEXT:    ret void
;
entry:
  %u.addr = alloca i32, align 4
  store i32 %u, i32* %u.addr, align 4
  %mul = mul i32 %u, 6
  %add6 = add i32 %mul, 6
  %idxprom = zext i32 %add6 to i64
  %arrayidx = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom
  %0 = load double, double* %arrayidx, align 8
  %arrayidx4 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom
  %1 = load double, double* %arrayidx4, align 8
  %add5 = fadd double %0, %1
  store double %add5, double* %arrayidx, align 8
  %add7 = add i32 %mul, 7
  %idxprom12 = zext i32 %add7 to i64
  %arrayidx13 = getelementptr inbounds [2000 x double], [2000 x double]* @A, i32 0, i64 %idxprom12
  %2 = load double, double* %arrayidx13, align 8
  %arrayidx17 = getelementptr inbounds [2000 x double], [2000 x double]* @B, i32 0, i64 %idxprom12
  %3 = load double, double* %arrayidx17, align 8
  %add18 = fadd double %2, %3
  store double %add18, double* %arrayidx13, align 8
  ret void
}

; Similar to foo_2double_non_power_of_2, but now we are dealing with AddRec SCEV.
; Alternatively, this is like foo_loop, but with a non-power-of-2 factor and
; potential wrapping (both indices wrap or both don't in the same time)
; Function Attrs: nounwind ssp uwtable
define i32 @foo_loop_non_power_of_2(double* %A, i32 %n) #0 {
; CHECK-LABEL: @foo_loop_non_power_of_2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_ADDR:%.*]] = alloca double*, align 8
; CHECK-NEXT:    [[N_ADDR:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[SUM:%.*]] = alloca double, align 8
; CHECK-NEXT:    [[I:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store double* [[A:%.*]], double** [[A_ADDR]], align 8
; CHECK-NEXT:    store i32 [[N:%.*]], i32* [[N_ADDR]], align 4
; CHECK-NEXT:    store double 0.000000e+00, double* [[SUM]], align 8
; CHECK-NEXT:    store i32 0, i32* [[I]], align 4
; CHECK-NEXT:    [[CMP1:%.*]] = icmp slt i32 0, [[N]]
; CHECK-NEXT:    br i1 [[CMP1]], label [[FOR_BODY_LR_PH:%.*]], label [[FOR_END:%.*]]
; CHECK:       for.body.lr.ph:
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i32 [ 0, [[FOR_BODY_LR_PH]] ], [ [[INC:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = phi double [ 0.000000e+00, [[FOR_BODY_LR_PH]] ], [ [[ADD7:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[MUL:%.*]] = mul i32 [[TMP0]], 12
; CHECK-NEXT:    [[ADD_5:%.*]] = add i32 [[MUL]], 5
; CHECK-NEXT:    [[IDXPROM:%.*]] = sext i32 [[ADD_5]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD_6:%.*]] = add i32 [[MUL]], 6
; CHECK-NEXT:    [[IDXPROM3:%.*]] = sext i32 [[ADD_6]] to i64
; CHECK-NEXT:    [[ARRAYIDX4:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IDXPROM3]]
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP3:%.*]] = load <2 x double>, <2 x double>* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = fmul <2 x double> <double 7.000000e+00, double 7.000000e+00>, [[TMP3]]
; CHECK-NEXT:    [[TMP5:%.*]] = extractelement <2 x double> [[TMP4]], i32 0
; CHECK-NEXT:    [[TMP6:%.*]] = extractelement <2 x double> [[TMP4]], i32 1
; CHECK-NEXT:    [[ADD6:%.*]] = fadd double [[TMP5]], [[TMP6]]
; CHECK-NEXT:    [[ADD7]] = fadd double [[TMP1]], [[ADD6]]
; CHECK-NEXT:    store double [[ADD7]], double* [[SUM]], align 8
; CHECK-NEXT:    [[INC]] = add i32 [[TMP0]], 1
; CHECK-NEXT:    store i32 [[INC]], i32* [[I]], align 4
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i32 [[INC]], [[N]]
; CHECK-NEXT:    br i1 [[CMP]], label [[FOR_BODY]], label [[FOR_COND_FOR_END_CRIT_EDGE:%.*]]
; CHECK:       for.cond.for.end_crit_edge:
; CHECK-NEXT:    [[SPLIT:%.*]] = phi double [ [[ADD7]], [[FOR_BODY]] ]
; CHECK-NEXT:    br label [[FOR_END]]
; CHECK:       for.end:
; CHECK-NEXT:    [[DOTLCSSA:%.*]] = phi double [ [[SPLIT]], [[FOR_COND_FOR_END_CRIT_EDGE]] ], [ 0.000000e+00, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[CONV:%.*]] = fptosi double [[DOTLCSSA]] to i32
; CHECK-NEXT:    ret i32 [[CONV]]
;
entry:
  %A.addr = alloca double*, align 8
  %n.addr = alloca i32, align 4
  %sum = alloca double, align 8
  %i = alloca i32, align 4
  store double* %A, double** %A.addr, align 8
  store i32 %n, i32* %n.addr, align 4
  store double 0.000000e+00, double* %sum, align 8
  store i32 0, i32* %i, align 4
  %cmp1 = icmp slt i32 0, %n
  br i1 %cmp1, label %for.body.lr.ph, label %for.end

for.body.lr.ph:                                   ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.lr.ph, %for.body
  %0 = phi i32 [ 0, %for.body.lr.ph ], [ %inc, %for.body ]
  %1 = phi double [ 0.000000e+00, %for.body.lr.ph ], [ %add7, %for.body ]
  %mul = mul i32 %0, 12
  %add.5 = add i32 %mul, 5
  %idxprom = sext i32 %add.5 to i64
  %arrayidx = getelementptr inbounds double, double* %A, i64 %idxprom
  %2 = load double, double* %arrayidx, align 8
  %mul1 = fmul double 7.000000e+00, %2
  %add.6 = add i32 %mul, 6
  %idxprom3 = sext i32 %add.6 to i64
  %arrayidx4 = getelementptr inbounds double, double* %A, i64 %idxprom3
  %3 = load double, double* %arrayidx4, align 8
  %mul5 = fmul double 7.000000e+00, %3
  %add6 = fadd double %mul1, %mul5
  %add7 = fadd double %1, %add6
  store double %add7, double* %sum, align 8
  %inc = add i32 %0, 1
  store i32 %inc, i32* %i, align 4
  %cmp = icmp slt i32 %inc, %n
  br i1 %cmp, label %for.body, label %for.cond.for.end_crit_edge

for.cond.for.end_crit_edge:                       ; preds = %for.body
  %split = phi double [ %add7, %for.body ]
  br label %for.end

for.end:                                          ; preds = %for.cond.for.end_crit_edge, %entry
  %.lcssa = phi double [ %split, %for.cond.for.end_crit_edge ], [ 0.000000e+00, %entry ]
  %conv = fptosi double %.lcssa to i32
  ret i32 %conv
}

; This is generated by `clang -std=c11 -Wpedantic -Wall -O3 main.c -S -o - -emit-llvm`
; with !{!"clang version 7.0.0 (trunk 337339) (llvm/trunk 337344)"} and stripping off
; the !tbaa metadata nodes to fit the rest of the test file, where `cat main.c` is:
;
;  double bar(double *a, unsigned n) {
;    double x = 0.0;
;    double y = 0.0;
;    for (unsigned i = 0; i < n; i += 2) {
;      x += a[i];
;      y += a[i + 1];
;    }
;    return x * y;
;  }
;
; The resulting IR is similar to @foo_loop, but with zext's instead of sext's.
;
; Make sure we are able to vectorize this from now on:
;
define double @bar(double* nocapture readonly %a, i32 %n) local_unnamed_addr #0 {
; CHECK-LABEL: @bar(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP15:%.*]] = icmp eq i32 [[N:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP15]], label [[FOR_COND_CLEANUP:%.*]], label [[FOR_BODY:%.*]]
; CHECK:       for.cond.cleanup:
; CHECK-NEXT:    [[TMP0:%.*]] = phi <2 x double> [ zeroinitializer, [[ENTRY:%.*]] ], [ [[TMP6:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = extractelement <2 x double> [[TMP0]], i32 0
; CHECK-NEXT:    [[TMP2:%.*]] = extractelement <2 x double> [[TMP0]], i32 1
; CHECK-NEXT:    [[MUL:%.*]] = fmul double [[TMP1]], [[TMP2]]
; CHECK-NEXT:    ret double [[MUL]]
; CHECK:       for.body:
; CHECK-NEXT:    [[I_018:%.*]] = phi i32 [ [[ADD5:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY]] ]
; CHECK-NEXT:    [[TMP3:%.*]] = phi <2 x double> [ [[TMP6]], [[FOR_BODY]] ], [ zeroinitializer, [[ENTRY]] ]
; CHECK-NEXT:    [[IDXPROM:%.*]] = zext i32 [[I_018]] to i64
; CHECK-NEXT:    [[ARRAYIDX:%.*]] = getelementptr inbounds double, double* [[A:%.*]], i64 [[IDXPROM]]
; CHECK-NEXT:    [[ADD1:%.*]] = or i32 [[I_018]], 1
; CHECK-NEXT:    [[IDXPROM2:%.*]] = zext i32 [[ADD1]] to i64
; CHECK-NEXT:    [[ARRAYIDX3:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IDXPROM2]]
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast double* [[ARRAYIDX]] to <2 x double>*
; CHECK-NEXT:    [[TMP5:%.*]] = load <2 x double>, <2 x double>* [[TMP4]], align 8
; CHECK-NEXT:    [[TMP6]] = fadd <2 x double> [[TMP3]], [[TMP5]]
; CHECK-NEXT:    [[ADD5]] = add i32 [[I_018]], 2
; CHECK-NEXT:    [[CMP:%.*]] = icmp ult i32 [[ADD5]], [[N]]
; CHECK-NEXT:    br i1 [[CMP]], label [[FOR_BODY]], label [[FOR_COND_CLEANUP]]
;
entry:
  %cmp15 = icmp eq i32 %n, 0
  br i1 %cmp15, label %for.cond.cleanup, label %for.body

for.cond.cleanup:                                 ; preds = %for.body, %entry
  %x.0.lcssa = phi double [ 0.000000e+00, %entry ], [ %add, %for.body ]
  %y.0.lcssa = phi double [ 0.000000e+00, %entry ], [ %add4, %for.body ]
  %mul = fmul double %x.0.lcssa, %y.0.lcssa
  ret double %mul

for.body:                                         ; preds = %entry, %for.body
  %i.018 = phi i32 [ %add5, %for.body ], [ 0, %entry ]
  %y.017 = phi double [ %add4, %for.body ], [ 0.000000e+00, %entry ]
  %x.016 = phi double [ %add, %for.body ], [ 0.000000e+00, %entry ]
  %idxprom = zext i32 %i.018 to i64
  %arrayidx = getelementptr inbounds double, double* %a, i64 %idxprom
  %0 = load double, double* %arrayidx, align 8
  %add = fadd double %x.016, %0
  %add1 = or i32 %i.018, 1
  %idxprom2 = zext i32 %add1 to i64
  %arrayidx3 = getelementptr inbounds double, double* %a, i64 %idxprom2
  %1 = load double, double* %arrayidx3, align 8
  %add4 = fadd double %y.017, %1
  %add5 = add i32 %i.018, 2
  %cmp = icmp ult i32 %add5, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup
}

; Globals/constant expressions are not normal constants.
; They should not be treated as the usual vectorization candidates.

@g1 = external global i32, align 4
@g2 = external global i32, align 4

define void @PR33958(i32** nocapture %p) {
; CHECK-LABEL: @PR33958(
; CHECK-NEXT:    store i32* @g1, i32** [[P:%.*]], align 8
; CHECK-NEXT:    [[ARRAYIDX1:%.*]] = getelementptr inbounds i32*, i32** [[P]], i64 1
; CHECK-NEXT:    store i32* @g2, i32** [[ARRAYIDX1]], align 8
; CHECK-NEXT:    ret void
;
  store i32* @g1, i32** %p, align 8
  %arrayidx1 = getelementptr inbounds i32*, i32** %p, i64 1
  store i32* @g2, i32** %arrayidx1, align 8
  ret void
}

define void @store_constant_expression(i64* %p) {
; CHECK-LABEL: @store_constant_expression(
; CHECK-NEXT:    store i64 ptrtoint (i32* @g1 to i64), i64* [[P:%.*]], align 8
; CHECK-NEXT:    [[ARRAYIDX1:%.*]] = getelementptr inbounds i64, i64* [[P]], i64 1
; CHECK-NEXT:    store i64 ptrtoint (i32* @g2 to i64), i64* [[ARRAYIDX1]], align 8
; CHECK-NEXT:    ret void
;
  store i64 ptrtoint (i32* @g1 to i64), i64* %p, align 8
  %arrayidx1 = getelementptr inbounds i64, i64* %p, i64 1
  store i64 ptrtoint (i32* @g2 to i64), i64* %arrayidx1, align 8
  ret void
}

attributes #0 = { nounwind ssp uwtable "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.ident = !{!0}

!0 = !{!"clang version 3.5.0 "}
