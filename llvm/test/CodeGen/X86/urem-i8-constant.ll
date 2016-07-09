; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: llc < %s -mtriple=i386-unknown-unknown | FileCheck %s

define i8 @foo(i8 %tmp325) {
; CHECK-LABEL: foo:
; CHECK:       # BB#0:
; CHECK-NEXT:    movzbl {{[0-9]+}}(%esp), %ecx
; CHECK-NEXT:    imull $111, %ecx, %eax
; CHECK-NEXT:    andl $28672, %eax # imm = 0x7000
; CHECK-NEXT:    shrl $12, %eax
; CHECK-NEXT:    movb $37, %dl
; CHECK-NEXT:    # kill: %AL<def> %AL<kill> %EAX<kill>
; CHECK-NEXT:    mulb %dl
; CHECK-NEXT:    subb %al, %cl
; CHECK-NEXT:    movl %ecx, %eax
; CHECK-NEXT:    retl
;
  %t546 = urem i8 %tmp325, 37
  ret i8 %t546
}

