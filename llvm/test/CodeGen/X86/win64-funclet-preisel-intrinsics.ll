; RUN: llc -mtriple=x86_64-windows-msvc < %s | FileCheck %s

; WinEH requires funclet tokens on nounwind intrinsics if they can lower to
; regular function calls in the course of IR transformations.
;
; Test that the code generator will emit the function call and not consider it
; an "implausible instruciton". In the past this silently truncated code on
; exception paths and caused crashes at runtime.
;
; Reduced IR generated from ObjC++ source:
;
;     @class Ety;
;     void opaque(void);
;     void test_catch_with_objc_intrinsic(void) {
;       @try {
;         opaque();
;       } @catch (Ety *ex) {
;         // Destroy ex when leaving catchpad. This would emit calls to two
;         // intrinsic functions: llvm.objc.retain and llvm.objc.storeStrong
;       }
;     }
;
; llvm.objc.retain and llvm.objc.storeStrong both lower into regular function
; calls before ISel. We only need one of them to trigger funclet truncation
; during codegen:

define void @test_catch_with_objc_intrinsic() personality ptr @__CxxFrameHandler3 {
entry:
  %exn.slot = alloca ptr, align 8
  %ex2 = alloca ptr, align 8
  invoke void @opaque() to label %invoke.cont unwind label %catch.dispatch

catch.dispatch:
  %0 = catchswitch within none [label %catch] unwind to caller

invoke.cont:                                      ; preds = %entry
  br label %eh.cont

eh.cont:                                          ; preds = %invoke.cont, %catchret.dest
  ret void

catch:
  %1 = catchpad within %0 [ptr null, i32 64, ptr %exn.slot]
  %exn = load ptr, ptr %exn.slot, align 8
  %2 = call ptr @llvm.objc.retain(ptr %exn) #0 [ "funclet"(token %1) ]
  store ptr %2, ptr %ex2, align 8
  catchret from %1 to label %catchret.dest

catchret.dest:
  ; Uncomment this line to fail the test:
  call void @llvm.objc.storeStrong(ptr %ex2, ptr null) #0 [ "funclet"(token %1) ]
  br label %eh.cont
}

declare void @opaque()
declare ptr @llvm.objc.retain(ptr) #0
declare void @llvm.objc.storeStrong(ptr, ptr) #0
declare i32 @__CxxFrameHandler3(...)

attributes #0 = { nounwind }

; TODO:
;                   # %catchret.dest
;     CHECK-LABEL:  $ehgcr
;     CHECK-NEXT:     nop
;     CHECK-NEXT:     addq	$64, %rsp
;     CHECK-NEXT:     popq	%rbp
;     CHECK-NEXT:     retq
;     CHECK-NEXT:     .seh_handlerdata
;
; EH catchpad with SEH prologue:
;     CHECK-LABEL:  # %catch
;     CHECK:        pushq   %rbp
;     CHECK:        .seh_pushreg %rbp
;                   ...
;     CHECK:        .seh_endprologue
;
; At this point the code used to be truncated (and sometimes terminated with an
; int3 opcode):
;     CHECK-NOT: int3
;
; Instead, the call to objc_storeStrong should be emitted:
;     CHECK: leaq	-24(%rbp), %rcx
;     CHECK: xorl	%edx, %edx
;     CHECK: callq	objc_storeStrong
;        ...
;
; This is the end of the funclet:
;     CHECK: popq	%rbp
;     CHECK: retq                                    # CATCHRET
;            ...
;     CHECK: .seh_handlerdata
;            ...
;     CHECK: .seh_endproc
