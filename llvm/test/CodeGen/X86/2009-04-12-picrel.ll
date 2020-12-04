; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -relocation-model=static -code-model=small | FileCheck %s

@dst = external dso_local global [131072 x i32]
@ptr = external dso_local global i32*

define void @off01(i64 %i) nounwind {
; CHECK-LABEL: off01:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    leaq dst+64(,%rdi,4), %rax
; CHECK-NEXT:    movq %rax, {{.*}}(%rip)
; CHECK-NEXT:    retq
entry:
	%.sum = add i64 %i, 16
	%0 = getelementptr [131072 x i32], [131072 x i32]* @dst, i64 0, i64 %.sum
	store i32* %0, i32** @ptr, align 8
	ret void
}
