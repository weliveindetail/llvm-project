; RUN: llc -mtriple=x86_64-windows-msvc < %s | FileCheck %s

; Reduced IR generated from ObjC++ source:
;
;     @class Ety;
;     void opaque(void);
;     void test_catch(void) {
;       @try {
;         opaque();
;       } @catch (Ety *ex) {
;         // Destroy ex when leaving catchpad. This emits calls to two intrinsic
;         // functions, llvm.objc.retain and llvm.objc.storeStrong, but only one
;         // is required to trigger the funclet truncation.
;       }
;     }

define void @test_catch() personality i8* bitcast (i32 (...)* @__CxxFrameHandler3 to i8*) {
entry:
  %exn.slot = alloca i8*, align 8
  %ex2 = alloca i8*, align 8
  invoke void @opaque() to label %invoke.cont unwind label %catch.dispatch

catch.dispatch:
  %0 = catchswitch within none [label %catch] unwind to caller

invoke.cont:
  unreachable

catch:
  %1 = catchpad within %0 [i8* null, i32 64, i8** %exn.slot]
  call void @llvm.objc.storeStrong(i8** %ex2, i8* null) [ "funclet"(token %1) ]
  catchret from %1 to label %catchret.dest

catchret.dest:
  ret void
}

declare void @opaque()
declare void @llvm.objc.storeStrong(i8**, i8*) #0
declare i32 @__CxxFrameHandler3(...)

attributes #0 = { nounwind }

; llvm.objc.storeStrong is a Pre-ISel intrinsic, which used to cause truncations
; when it occurred in SEH funclets like catchpads:
;     CHECK: # %catch
;     CHECK: pushq   %rbp
;     CHECK: .seh_pushreg %rbp
;            ...
;     CHECK: .seh_endprologue
;
; At this point the code used to be truncated:
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
