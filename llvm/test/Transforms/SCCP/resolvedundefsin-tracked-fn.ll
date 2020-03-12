; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature
; RUN: opt -ipsccp -S %s | FileCheck %s

%t1 = type opaque

@e = common global i32 0, align 4

; Test that we a skip unknown values depending on a unknown tracked call, until the call gets resolved. The @test1 and @test2 variants are very similar, they just check 2 different kinds of users (icmp and zext)

define i32 @test1_m(i32 %h) {
; CHECK-LABEL: define {{[^@]+}}@test1_m
; CHECK-SAME: (i32 [[H:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CONV:%.*]] = trunc i32 [[H]] to i8
; CHECK-NEXT:    [[CALL:%.*]] = call i32 @test1_k(i8 [[CONV]], i32 0)
; CHECK-NEXT:    [[CONV1:%.*]] = sext i32 [[H]] to i64
; CHECK-NEXT:    [[TMP0:%.*]] = inttoptr i64 [[CONV1]] to %t1*
; CHECK-NEXT:    [[CALL2:%.*]] = call i1 @test1_g(%t1* [[TMP0]], i32 1)
; CHECK-NEXT:    ret i32 undef
;
entry:
  %conv = trunc i32 %h to i8
  %call = call i32 @test1_k(i8 %conv, i32 0)
  %conv1 = sext i32 %h to i64
  %0 = inttoptr i64 %conv1 to %t1*
  %call2 = call i1 @test1_g(%t1* %0, i32 1)
  ret i32 undef

; uselistorder directives
  uselistorder i32 %h, { 1, 0 }
}

declare void @use.1(i1)

define internal i32 @test1_k(i8 %h, i32 %i) {
; CHECK-LABEL: define {{[^@]+}}@test1_k
; CHECK-SAME: (i8 [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i32, i32* @e, align 4
; CHECK-NEXT:    [[CONV:%.*]] = sext i32 [[TMP0]] to i64
; CHECK-NEXT:    [[TMP1:%.*]] = inttoptr i64 [[CONV]] to %t1*
; CHECK-NEXT:    [[CALL:%.*]] = call i1 @test1_g(%t1* [[TMP1]], i32 0)
; CHECK-NEXT:    [[FROMBOOL_1:%.*]] = zext i1 false to i8
; CHECK-NEXT:    [[TOBOOL_1:%.*]] = trunc i8 [[FROMBOOL_1]] to i1
; CHECK-NEXT:    call void @use.1(i1 [[TOBOOL_1]])
; CHECK-NEXT:    ret i32 undef
;
entry:
  %0 = load i32, i32* @e, align 4
  %conv = sext i32 %0 to i64
  %1 = inttoptr i64 %conv to %t1*
  %call = call i1 @test1_g(%t1* %1, i32 %i)
  %frombool.1 = zext i1 %call to i8
  %tobool.1 = trunc i8 %frombool.1 to i1
  call void @use.1(i1 %tobool.1)
  ret i32 undef
}

define internal i1 @test1_g(%t1* %h, i32 %i) #0 {
; CHECK-LABEL: define {{[^@]+}}@test1_g
; CHECK-SAME: (%t1* [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp ne i32 [[I]], 0
; CHECK-NEXT:    br i1 [[TOBOOL]], label [[LAND_RHS:%.*]], label [[LAND_END:%.*]]
; CHECK:       land.rhs:
; CHECK-NEXT:    [[CALL:%.*]] = call i32 (...) @test1_j()
; CHECK-NEXT:    [[TOBOOL1:%.*]] = icmp ne i32 [[CALL]], 0
; CHECK-NEXT:    br label [[LAND_END]]
; CHECK:       land.end:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i1 [ false, [[ENTRY:%.*]] ], [ [[TOBOOL1]], [[LAND_RHS]] ]
; CHECK-NEXT:    ret i1 undef
;
entry:
  %tobool = icmp ne i32 %i, 0
  br i1 %tobool, label %land.rhs, label %land.end

land.rhs:                                         ; preds = %entry
  %call = call i32 (...) @test1_j()
  %tobool1 = icmp ne i32 %call, 0
  br label %land.end

land.end:                                         ; preds = %land.rhs, %entry
  %0 = phi i1 [ false, %entry ], [ %tobool1, %land.rhs ]
  ret i1 false
}

declare i32 @test1_j(...)

define i32 @test2_m(i32 %h) #0 {
; CHECK-LABEL: define {{[^@]+}}@test2_m
; CHECK-SAME: (i32 [[H:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CONV:%.*]] = trunc i32 [[H]] to i8
; CHECK-NEXT:    [[CALL:%.*]] = call i32 @test2_k(i8 [[CONV]], i32 0)
; CHECK-NEXT:    [[CONV1:%.*]] = sext i32 [[H]] to i64
; CHECK-NEXT:    [[TMP0:%.*]] = inttoptr i64 [[CONV1]] to %t1*
; CHECK-NEXT:    [[CALL2:%.*]] = call i1 @test2_g(%t1* [[TMP0]], i32 1)
; CHECK-NEXT:    ret i32 undef
;
entry:
  %conv = trunc i32 %h to i8
  %call = call i32 @test2_k(i8 %conv, i32 0)
  %conv1 = sext i32 %h to i64
  %0 = inttoptr i64 %conv1 to %t1*
  %call2 = call i1 @test2_g(%t1* %0, i32 1)
  ret i32 undef

; uselistorder directives
  uselistorder i32 %h, { 1, 0 }
}

; TODO: We could do better for the return value of call i1 @test3_g, if we
;       resolve the unknown values there first.
define internal i32 @test2_k(i8 %h, i32 %i) {
; CHECK-LABEL: define {{[^@]+}}@test2_k
; CHECK-SAME: (i8 [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i32, i32* @e, align 4
; CHECK-NEXT:    [[CONV:%.*]] = sext i32 [[TMP0]] to i64
; CHECK-NEXT:    [[TMP1:%.*]] = inttoptr i64 [[CONV]] to %t1*
; CHECK-NEXT:    [[CALL:%.*]] = call i1 @test3_g(%t1* [[TMP1]], i32 0)
; CHECK-NEXT:    [[FROMBOOL:%.*]] = icmp slt i1 false, true
; CHECK-NEXT:    [[ADD:%.*]] = add i1 [[FROMBOOL]], [[FROMBOOL]]
; CHECK-NEXT:    call void @use.1(i1 [[FROMBOOL]])
; CHECK-NEXT:    ret i32 undef
;
entry:
  %0 = load i32, i32* @e, align 4
  %conv = sext i32 %0 to i64
  %1 = inttoptr i64 %conv to %t1*
  %call = call i1 @test3_g(%t1* %1, i32 %i)
  %frombool = icmp slt i1 %call, 1
  %add = add i1 %frombool, %frombool
  call void @use.1(i1 %frombool)
  ret i32 undef

}

define internal i1 @test2_g(%t1* %h, i32 %i) {
; CHECK-LABEL: define {{[^@]+}}@test2_g
; CHECK-SAME: (%t1* [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 true, label [[LAND_RHS:%.*]], label [[LAND_END:%.*]]
; CHECK:       land.rhs:
; CHECK-NEXT:    [[CALL:%.*]] = call i32 (...) @test2_j()
; CHECK-NEXT:    [[TOBOOL1:%.*]] = icmp ne i32 [[CALL]], 0
; CHECK-NEXT:    br label [[LAND_END]]
; CHECK:       land.end:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i1 [ false, [[ENTRY:%.*]] ], [ [[TOBOOL1]], [[LAND_RHS]] ]
; CHECK-NEXT:    ret i1 undef
;
entry:
  %tobool = icmp ne i32 %i, 0
  br i1 %tobool, label %land.rhs, label %land.end

land.rhs:                                         ; preds = %entry
  %call = call i32 (...) @test2_j()
  %tobool1 = icmp ne i32 %call, 0
  br label %land.end

land.end:                                         ; preds = %land.rhs, %entry
  %0 = phi i1 [ false, %entry ], [ %tobool1, %land.rhs ]
  ret i1 false
}

declare i32 @test2_j(...)



; Same as test_2*, but with a PHI node depending on a tracked  call result.
define i32 @test3_m(i32 %h) #0 {
; CHECK-LABEL: define {{[^@]+}}@test3_m
; CHECK-SAME: (i32 [[H:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CONV:%.*]] = trunc i32 [[H]] to i8
; CHECK-NEXT:    [[CALL:%.*]] = call i32 @test3_k(i8 [[CONV]], i32 0)
; CHECK-NEXT:    [[CONV1:%.*]] = sext i32 [[H]] to i64
; CHECK-NEXT:    [[TMP0:%.*]] = inttoptr i64 [[CONV1]] to %t1*
; CHECK-NEXT:    [[CALL2:%.*]] = call i1 @test3_g(%t1* [[TMP0]], i32 1)
; CHECK-NEXT:    ret i32 undef
;
entry:
  %conv = trunc i32 %h to i8
  %call = call i32 @test3_k(i8 %conv, i32 0)
  %conv1 = sext i32 %h to i64
  %0 = inttoptr i64 %conv1 to %t1*
  %call2 = call i1 @test3_g(%t1* %0, i32 1)
  ret i32 undef

; uselistorder directives
  uselistorder i32 %h, { 1, 0 }
}

define internal i32 @test3_k(i8 %h, i32 %i) {
; CHECK-LABEL: define {{[^@]+}}@test3_k
; CHECK-SAME: (i8 [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i32, i32* @e, align 4
; CHECK-NEXT:    [[CONV:%.*]] = sext i32 [[TMP0]] to i64
; CHECK-NEXT:    [[TMP1:%.*]] = inttoptr i64 [[CONV]] to %t1*
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[PHI:%.*]] = phi i1 [ undef, [[ENTRY:%.*]] ], [ false, [[LOOP]] ]
; CHECK-NEXT:    [[CALL:%.*]] = call i1 @test3_g(%t1* [[TMP1]], i32 0)
; CHECK-NEXT:    call void @use.1(i1 false)
; CHECK-NEXT:    br i1 false, label [[LOOP]], label [[EXIT:%.*]]
; CHECK:       exit:
; CHECK-NEXT:    ret i32 undef
;
entry:
  %0 = load i32, i32* @e, align 4
  %conv = sext i32 %0 to i64
  %1 = inttoptr i64 %conv to %t1*
  br label %loop

loop:
  %phi = phi i1 [ undef, %entry], [ %call, %loop ]
  %call = call i1 @test3_g(%t1* %1, i32 %i)
  %frombool = icmp slt i1 %call, 1
  %add = add i1 %frombool, %frombool
  call void @use.1(i1 %frombool)
  br i1 %call, label %loop, label %exit

exit:
  ret i32 undef
}

define internal i1 @test3_g(%t1* %h, i32 %i) {
; CHECK-LABEL: define {{[^@]+}}@test3_g
; CHECK-SAME: (%t1* [[H:%.*]], i32 [[I:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp ne i32 [[I]], 0
; CHECK-NEXT:    br i1 [[TOBOOL]], label [[LAND_RHS:%.*]], label [[LAND_END:%.*]]
; CHECK:       land.rhs:
; CHECK-NEXT:    [[CALL:%.*]] = call i32 (...) @test3_j()
; CHECK-NEXT:    [[TOBOOL1:%.*]] = icmp ne i32 [[CALL]], 0
; CHECK-NEXT:    br label [[LAND_END]]
; CHECK:       land.end:
; CHECK-NEXT:    [[TMP0:%.*]] = phi i1 [ false, [[ENTRY:%.*]] ], [ [[TOBOOL1]], [[LAND_RHS]] ]
; CHECK-NEXT:    ret i1 undef
;
entry:
  %tobool = icmp ne i32 %i, 0
  br i1 %tobool, label %land.rhs, label %land.end

land.rhs:                                         ; preds = %entry
  %call = call i32 (...) @test3_j()
  %tobool1 = icmp ne i32 %call, 0
  br label %land.end

land.end:                                         ; preds = %land.rhs, %entry
  %0 = phi i1 [ false, %entry ], [ %tobool1, %land.rhs ]
  ret i1 false
}

declare i32 @test3_j(...)


; TODO: We can eliminate the bitcast, if we resolve the unknown argument of
;       @test4_b first.

declare void @use.16(i16*)
declare void @use.8(i8*)

define void @test4_a() {
; CHECK-LABEL: define {{[^@]+}}@test4_a()
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[TMP:%.*]] = call i8* @test4_c(i8* null)
; CHECK-NEXT:    call void @test4_b(i8* null)
; CHECK-NEXT:    ret void
;
bb:
  %tmp = call i8* @test4_c(i8* null)
  call void @test4_b(i8* %tmp)
  ret void
}

define internal void @test4_b(i8* %arg) {
; CHECK-LABEL: define {{[^@]+}}@test4_b
; CHECK-SAME: (i8* [[ARG:%.*]])
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[TMP:%.*]] = bitcast i8* null to i16*
; CHECK-NEXT:    call void @use.16(i16* [[TMP]])
; CHECK-NEXT:    call void @use.8(i8* null)
; CHECK-NEXT:    ret void
;
bb:
  %tmp = bitcast i8* %arg to i16*
  %sel = select i1 false, i8* %arg, i8* %arg
  call void @use.16(i16* %tmp)
  call void @use.8(i8* %sel)
  ret void
}

define internal i8* @test4_c(i8* %arg) {
; CHECK-LABEL: define {{[^@]+}}@test4_c
; CHECK-SAME: (i8* [[ARG:%.*]])
; CHECK-NEXT:  bb1:
; CHECK-NEXT:    [[TMP:%.*]] = and i1 undef, undef
; CHECK-NEXT:    br i1 [[TMP]], label [[BB3:%.*]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    unreachable
; CHECK:       bb3:
; CHECK-NEXT:    ret i8* undef
;
bb1:                                              ; preds = %bb
  %tmp = and i1 undef, undef
  br i1 %tmp, label %bb3, label %bb2

bb2:                                              ; preds = %bb1
  unreachable

bb3:                                              ; preds = %bb1
  ret i8* null
}

; TODO: Same as test4, but with a select instead of a bitcast.

define void @test5_a() {
; CHECK-LABEL: define {{[^@]+}}@test5_a()
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[TMP:%.*]] = call i8* @test5_c(i8* null)
; CHECK-NEXT:    call void @test5_b(i8* null)
; CHECK-NEXT:    ret void
;
bb:
  %tmp = call i8* @test5_c(i8* null)
  call void @test5_b(i8* %tmp)
  ret void
}

define internal void @test5_b(i8* %arg) {
; CHECK-LABEL: define {{[^@]+}}@test5_b
; CHECK-SAME: (i8* [[ARG:%.*]])
; CHECK-NEXT:  bb:
; CHECK-NEXT:    [[SEL:%.*]] = select i1 false, i8* null, i8* null
; CHECK-NEXT:    call void @use.8(i8* [[SEL]])
; CHECK-NEXT:    ret void
;
bb:
  %sel = select i1 false, i8* %arg, i8* %arg
  call void @use.8(i8* %sel)
  ret void
}

define internal i8* @test5_c(i8* %arg) {
; CHECK-LABEL: define {{[^@]+}}@test5_c
; CHECK-SAME: (i8* [[ARG:%.*]])
; CHECK-NEXT:  bb1:
; CHECK-NEXT:    [[TMP:%.*]] = and i1 undef, undef
; CHECK-NEXT:    br i1 [[TMP]], label [[BB3:%.*]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    unreachable
; CHECK:       bb3:
; CHECK-NEXT:    ret i8* undef
;
bb1:                                              ; preds = %bb
  %tmp = and i1 undef, undef
  br i1 %tmp, label %bb3, label %bb2

bb2:                                              ; preds = %bb1
  unreachable

bb3:                                              ; preds = %bb1
  ret i8* null
}



@contextsize = external dso_local local_unnamed_addr global i32, align 4
@pcount = internal local_unnamed_addr global i32 0, align 4
@maxposslen = external dso_local local_unnamed_addr global i32, align 4

define void @test3() {
; CHECK-LABEL: define {{[^@]+}}@test3()
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[IF_END16:%.*]]
; CHECK:       if.end16:
; CHECK-NEXT:    [[TMP0:%.*]] = load i32, i32* @contextsize, align 4
; CHECK-NEXT:    [[SUB18:%.*]] = sub i32 undef, [[TMP0]]
; CHECK-NEXT:    [[SUB19:%.*]] = sub i32 [[SUB18]], undef
; CHECK-NEXT:    [[TMP1:%.*]] = load i32, i32* @maxposslen, align 4
; CHECK-NEXT:    [[ADD:%.*]] = add nsw i32 [[TMP1]], 8
; CHECK-NEXT:    [[DIV:%.*]] = sdiv i32 undef, [[ADD]]
; CHECK-NEXT:    [[TMP2:%.*]] = load i32, i32* @pcount, align 4
; CHECK-NEXT:    [[MUL:%.*]] = mul nsw i32 [[DIV]], [[SUB19]]
; CHECK-NEXT:    [[CMP20:%.*]] = icmp sgt i32 [[TMP2]], [[MUL]]
; CHECK-NEXT:    br i1 [[CMP20]], label [[IF_THEN22:%.*]], label [[IF_END24:%.*]]
; CHECK:       if.then22:
; CHECK-NEXT:    store i32 [[MUL]], i32* @pcount, align 4
; CHECK-NEXT:    ret void
; CHECK:       if.end24:
; CHECK-NEXT:    [[CMP25474:%.*]] = icmp sgt i32 [[TMP2]], 0
; CHECK-NEXT:    br i1 [[CMP25474]], label [[FOR_BODY:%.*]], label [[FOR_END:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[DIV30:%.*]] = sdiv i32 0, [[SUB19]]
; CHECK-NEXT:    ret void
; CHECK:       for.end:
; CHECK-NEXT:    ret void
;
entry:
  br label %if.end16

if.end16:                                         ; preds = %entry
  %0 = load i32, i32* @contextsize, align 4
  %sub18 = sub i32 undef, %0
  %sub19 = sub i32 %sub18, undef
  %1 = load i32, i32* @maxposslen, align 4
  %add = add nsw i32 %1, 8
  %div = sdiv i32 undef, %add
  %2 = load i32, i32* @pcount, align 4
  %mul = mul nsw i32 %div, %sub19
  %cmp20 = icmp sgt i32 %2, %mul
  br i1 %cmp20, label %if.then22, label %if.end24

if.then22:                                        ; preds = %if.end16
  store i32 %mul, i32* @pcount, align 4
  ret void

if.end24:                                         ; preds = %if.end16
  %cmp25474 = icmp sgt i32 %2, 0
  br i1 %cmp25474, label %for.body, label %for.end

for.body:                                         ; preds = %if.end24
  %3 = trunc i64 0 to i32
  %div30 = sdiv i32 %3, %sub19
  ret void

for.end:                                          ; preds = %if.end24
  ret void
}
