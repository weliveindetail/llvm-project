; RUN: llc -mtriple=x86_64-windows-msvc < %s | FileCheck %s

; Reduced IR generated from ObjC++ source:
;
;     __attribute__((always_inline)) void inlined_fn(id ex) {}
;     int main(void) {
;       @try {
;         id ex1 = [Test new];
;         @throw ex1;
;       } @catch (id ex1) {
;         id ex2 = [Test new];
;         inlined_fn(ex2);
;       }
;       return 0;
;     }

%rtti.TypeDescriptor18 = type { i8**, i8*, [19 x i8] }

@"$_OBJC_REF_CLASS_Test" = local_unnamed_addr global i8* undef, section ".objcrt$CLR$m"
@"??_R0PEAUobjc_object@@@8" = linkonce_odr global %rtti.TypeDescriptor18 { i8** undef, i8* null, [19 x i8] c".PEAUobjc_object@@\00" }, comdat
$"??_R0PEAUobjc_object@@@8" = comdat any

declare i32 @__CxxFrameHandler3(...)
declare i8* @objc_msgSend(...) local_unnamed_addr
declare void @objc_exception_throw() local_unnamed_addr
declare void @llvm.objc.release(i8*) #0

define i32 @main() local_unnamed_addr personality i8* bitcast (i32 (...)* @__CxxFrameHandler3 to i8*) {
invoke.cont:
  invoke void bitcast (void ()* @objc_exception_throw to void (i8*)*)(i8* undef)
          to label %invoke.cont1 unwind label %catch.dispatch, !clang.arc.no_objc_arc_exceptions !0

invoke.cont1:  unreachable

catch.dispatch:  %0 = catchswitch within none [label %catch] unwind to caller

catch:  %1 = catchpad within %0 [i8* bitcast (%rtti.TypeDescriptor18* @"??_R0PEAUobjc_object@@@8" to i8*), i32 0, i8** undef]
  %2 = load i8*, i8** @"$_OBJC_REF_CLASS_Test", align 8
  %call3 = call i8* bitcast (i8* (...)* @objc_msgSend to i8* (i8*, i8*)*)(i8* %2, i8* undef) [ "funclet"(token %1) ], !clang.arc.no_objc_arc_exceptions !0, !GNUObjCMessageSend !1
  call void @llvm.objc.release(i8* %call3) [ "funclet"(token %1) ], !clang.imprecise_release !0
  catchret from %1 to label %catchret.dest

catchret.dest:  ret i32 0
}

attributes #0 = { nounwind }

!0 = !{}
!1 = !{!"new", !"Test", i1 true}

; llvm.objc.release is a Pre-ISel intrinsic, which used to cause truncations
; when it occurred in SEH funclets like catchpads:
;     CHECK: # %catch
;     CHECK: pushq   %rbp
;     CHECK: .seh_pushreg %rbp
;            ...
;     CHECK: .seh_endprologue
;     CHECK: movq	($_OBJC_REF_CLASS_Test)(%rip), %rcx
;     CHECK: allq	objc_msgSend
;
; At this point the code used to be truncated:
;     CHECK-NOT: int3
;
; Instead, the call to objc_release should be emitted:
;     CHECK: movq	%rax, %rcx
;     CHECK: callq	objc_release
;        ...
; 
; This is the end of the funclet:
;     CHECK: popq	%rbp
;     CHECK: retq                                    # CATCHRET
;            ...
;     CHECK: .seh_handlerdata
;            ...
;     CHECK: .seh_endproc
