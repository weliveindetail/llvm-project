; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -S -verify -iroutliner < %s | FileCheck %s

; This is a negative case to show that when we have the same set of
; instructions, but in a different order, they are not outlined in the same way.
; In this case, the arguments passed into the function are in a different order.

define void @outline_constants1() {
; CHECK-LABEL: @outline_constants1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[B:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[C:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 2, i32* [[A]], align 4
; CHECK-NEXT:    store i32 3, i32* [[B]], align 4
; CHECK-NEXT:    store i32 4, i32* [[C]], align 4
; CHECK-NEXT:    call void @[[FUNCTION_0:.*]](i32* [[A]], i32* [[C]], i32* [[B]])
; CHECK-NEXT:    ret void
;
entry:
  %a = alloca i32, align 4
  %b = alloca i32, align 4
  %c = alloca i32, align 4
  store i32 2, i32* %a, align 4
  store i32 3, i32* %b, align 4
  store i32 4, i32* %c, align 4
  %al = load i32, i32* %a
  %cl = load i32, i32* %c
  %bl = load i32, i32* %b
  ret void
}

define void @outline_constants2() {
; CHECK-LABEL: @outline_constants2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[B:%.*]] = alloca i32, align 4
; CHECK-NEXT:    [[C:%.*]] = alloca i32, align 4
; CHECK-NEXT:    store i32 2, i32* [[A]], align 4
; CHECK-NEXT:    store i32 3, i32* [[B]], align 4
; CHECK-NEXT:    store i32 4, i32* [[C]], align 4
; CHECK-NEXT:    call void @[[FUNCTION_1:.*]](i32* [[A]], i32* [[B]], i32* [[C]])
; CHECK-NEXT:    ret void
;
entry:
  %a = alloca i32, align 4
  %b = alloca i32, align 4
  %c = alloca i32, align 4
  store i32 2, i32* %a, align 4
  store i32 3, i32* %b, align 4
  store i32 4, i32* %c, align 4
  %al = load i32, i32* %a
  %bl = load i32, i32* %b
  %cl = load i32, i32* %c
  ret void
}

; CHECK: define internal void @[[FUNCTION_0]](i32* [[ARG0:%.*]], i32* [[ARG1:%.*]], i32* [[ARG2:%.*]])
; CHECK: entry_to_outline:
; CHECK-NEXT:    [[AL:%.*]] = load i32, i32* [[ARG0]], align 4
; CHECK-NEXT:    [[BL:%.*]] = load i32, i32* [[ARG1]], align 4
; CHECK-NEXT:    [[CL:%.*]] = load i32, i32* [[ARG2]], align 4

; CHECK: define internal void @[[FUNCTION_1]](i32* [[ARG0:%.*]], i32* [[ARG1:%.*]], i32* [[ARG2:%.*]])
; CHECK: entry_to_outline:
; CHECK-NEXT:    [[AL:%.*]] = load i32, i32* [[ARG0]], align 4
; CHECK-NEXT:    [[BL:%.*]] = load i32, i32* [[ARG1]], align 4
; CHECK-NEXT:    [[CL:%.*]] = load i32, i32* [[ARG2]], align 4
