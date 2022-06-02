; RUN: llc -mtriple=x86_64-windows-msvc < %s | FileCheck %s

; Reduced IR generated from ObjC++ source:
;
;     int main(void) {
;       id ex1 = [Test new]; // Destroy when leaving main function (used to work)
;       @try {
;         @throw ex1;
;       } @catch (...) {
;         id ex2 = [Test new]; // Destroy when leaving catchpad (D124762)
;       }
;       return 0;
;     }

@"$_OBJC_REF_CLASS_Test" = global i8* undef, section ".objcrt$CLR$m"

define i32 @main() personality i8* bitcast (i32 (...)* @__CxxFrameHandler3 to i8*) {
entry:
  %exn.slot = alloca i8*, align 8
  %ex2 = alloca i8*, align 8
  invoke void bitcast (void ()* @objc_exception_throw to void (i8*)*)(i8* undef)
          to label %invoke.cont unwind label %catch.dispatch

catch.dispatch:
  %0 = catchswitch within none [label %catch] unwind to caller

invoke.cont:
  unreachable

catch:
  %1 = catchpad within %0 [i8* null, i32 64, i8** %exn.slot]
  call void @llvm.objc.storeStrong(i8** %ex2, i8* null) [ "funclet"(token %1) ]
  catchret from %1 to label %catchret.dest

catchret.dest:
  ret i32 undef
}

declare i32 @__CxxFrameHandler3(...)
declare void @objc_exception_throw()
declare void @llvm.objc.storeStrong(i8**, i8*) #0

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
