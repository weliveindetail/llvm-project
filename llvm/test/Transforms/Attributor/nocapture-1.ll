; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --scrub-attributes
; RUN: opt -attributor -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=6 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_NPM,NOT_CGSCC_OPM,NOT_TUNIT_NPM,IS__TUNIT____,IS________OPM,IS__TUNIT_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=6 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_OPM,NOT_CGSCC_NPM,NOT_TUNIT_OPM,IS__TUNIT____,IS________NPM,IS__TUNIT_NPM
; RUN: opt -attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_NPM,IS__CGSCC____,IS________OPM,IS__CGSCC_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_OPM,IS__CGSCC____,IS________NPM,IS__CGSCC_NPM

@g = global i32* null		; <i32**> [#uses=1]

define i32* @c1(i32* %q) {
; CHECK-LABEL: define {{[^@]+}}@c1
; CHECK-SAME: (i32* nofree readnone returned "no-capture-maybe-returned" [[Q:%.*]])
; CHECK-NEXT:    ret i32* [[Q]]
;
  ret i32* %q
}

; It would also be acceptable to mark %q as readnone. Update @c3 too.
define void @c2(i32* %q) {
; CHECK-LABEL: define {{[^@]+}}@c2
; CHECK-SAME: (i32* nofree writeonly [[Q:%.*]])
; CHECK-NEXT:    store i32* [[Q]], i32** @g, align 8
; CHECK-NEXT:    ret void
;
  store i32* %q, i32** @g
  ret void
}

define void @c3(i32* %q) {
; CHECK-LABEL: define {{[^@]+}}@c3
; CHECK-SAME: (i32* nofree writeonly [[Q:%.*]])
; CHECK-NEXT:    call void @c2(i32* nofree writeonly [[Q]])
; CHECK-NEXT:    ret void
;
  call void @c2(i32* %q)
  ret void
}

define i1 @c4(i32* %q, i32 %bitno) {
; CHECK-LABEL: define {{[^@]+}}@c4
; CHECK-SAME: (i32* nofree readnone [[Q:%.*]], i32 [[BITNO:%.*]])
; CHECK-NEXT:    [[TMP:%.*]] = ptrtoint i32* [[Q]] to i32
; CHECK-NEXT:    [[TMP2:%.*]] = lshr i32 [[TMP]], [[BITNO]]
; CHECK-NEXT:    [[BIT:%.*]] = trunc i32 [[TMP2]] to i1
; CHECK-NEXT:    br i1 [[BIT]], label [[L1:%.*]], label [[L0:%.*]]
; CHECK:       l0:
; CHECK-NEXT:    ret i1 false
; CHECK:       l1:
; CHECK-NEXT:    ret i1 true
;
  %tmp = ptrtoint i32* %q to i32
  %tmp2 = lshr i32 %tmp, %bitno
  %bit = trunc i32 %tmp2 to i1
  br i1 %bit, label %l1, label %l0
l0:
  ret i1 0 ; escaping value not caught by def-use chaining.
l1:
  ret i1 1 ; escaping value not caught by def-use chaining.
}

; c4b is c4 but without the escaping part
define i1 @c4b(i32* %q, i32 %bitno) {
; CHECK-LABEL: define {{[^@]+}}@c4b
; CHECK-SAME: (i32* nocapture nofree readnone [[Q:%.*]], i32 [[BITNO:%.*]])
; CHECK-NEXT:    [[TMP:%.*]] = ptrtoint i32* [[Q]] to i32
; CHECK-NEXT:    [[TMP2:%.*]] = lshr i32 [[TMP]], [[BITNO]]
; CHECK-NEXT:    [[BIT:%.*]] = trunc i32 [[TMP2]] to i1
; CHECK-NEXT:    br i1 [[BIT]], label [[L1:%.*]], label [[L0:%.*]]
; CHECK:       l0:
; CHECK-NEXT:    ret i1 false
; CHECK:       l1:
; CHECK-NEXT:    ret i1 false
;
  %tmp = ptrtoint i32* %q to i32
  %tmp2 = lshr i32 %tmp, %bitno
  %bit = trunc i32 %tmp2 to i1
  br i1 %bit, label %l1, label %l0
l0:
  ret i1 0 ; not escaping!
l1:
  ret i1 0 ; not escaping!
}

@lookup_table = global [2 x i1] [ i1 0, i1 1 ]

define i1 @c5(i32* %q, i32 %bitno) {
; CHECK-LABEL: define {{[^@]+}}@c5
; CHECK-SAME: (i32* nofree readonly [[Q:%.*]], i32 [[BITNO:%.*]])
; CHECK-NEXT:    [[TMP:%.*]] = ptrtoint i32* [[Q]] to i32
; CHECK-NEXT:    [[TMP2:%.*]] = lshr i32 [[TMP]], [[BITNO]]
; CHECK-NEXT:    [[BIT:%.*]] = and i32 [[TMP2]], 1
; CHECK-NEXT:    [[LOOKUP:%.*]] = getelementptr [2 x i1], [2 x i1]* @lookup_table, i32 0, i32 [[BIT]]
; CHECK-NEXT:    [[VAL:%.*]] = load i1, i1* [[LOOKUP]], align 1
; CHECK-NEXT:    ret i1 [[VAL]]
;
  %tmp = ptrtoint i32* %q to i32
  %tmp2 = lshr i32 %tmp, %bitno
  %bit = and i32 %tmp2, 1
  ; subtle escape mechanism follows
  %lookup = getelementptr [2 x i1], [2 x i1]* @lookup_table, i32 0, i32 %bit
  %val = load i1, i1* %lookup
  ret i1 %val
}

declare void @throw_if_bit_set(i8*, i8) readonly

define i1 @c6(i8* %q, i8 %bit) personality i32 (...)* @__gxx_personality_v0 {
; CHECK-LABEL: define {{[^@]+}}@c6
; CHECK-SAME: (i8* readonly [[Q:%.*]], i8 [[BIT:%.*]]) #4 personality i32 (...)* @__gxx_personality_v0
; CHECK-NEXT:    invoke void @throw_if_bit_set(i8* readonly [[Q]], i8 [[BIT]])
; CHECK-NEXT:    to label [[RET0:%.*]] unwind label [[RET1:%.*]]
; CHECK:       ret0:
; CHECK-NEXT:    ret i1 false
; CHECK:       ret1:
; CHECK-NEXT:    [[EXN:%.*]] = landingpad { i8*, i32 }
; CHECK-NEXT:    cleanup
; CHECK-NEXT:    ret i1 true
;
  invoke void @throw_if_bit_set(i8* %q, i8 %bit)
  to label %ret0 unwind label %ret1
ret0:
  ret i1 0
ret1:
  %exn = landingpad {i8*, i32}
  cleanup
  ret i1 1
}

declare i32 @__gxx_personality_v0(...)

define i1* @lookup_bit(i32* %q, i32 %bitno) readnone nounwind {
; CHECK-LABEL: define {{[^@]+}}@lookup_bit
; CHECK-SAME: (i32* nofree readnone [[Q:%.*]], i32 [[BITNO:%.*]])
; CHECK-NEXT:    [[TMP:%.*]] = ptrtoint i32* [[Q]] to i32
; CHECK-NEXT:    [[TMP2:%.*]] = lshr i32 [[TMP]], [[BITNO]]
; CHECK-NEXT:    [[BIT:%.*]] = and i32 [[TMP2]], 1
; CHECK-NEXT:    [[LOOKUP:%.*]] = getelementptr [2 x i1], [2 x i1]* @lookup_table, i32 0, i32 [[BIT]]
; CHECK-NEXT:    ret i1* [[LOOKUP]]
;
  %tmp = ptrtoint i32* %q to i32
  %tmp2 = lshr i32 %tmp, %bitno
  %bit = and i32 %tmp2, 1
  %lookup = getelementptr [2 x i1], [2 x i1]* @lookup_table, i32 0, i32 %bit
  ret i1* %lookup
}

define i1 @c7(i32* %q, i32 %bitno) {
; CHECK-LABEL: define {{[^@]+}}@c7
; CHECK-SAME: (i32* nofree readonly [[Q:%.*]], i32 [[BITNO:%.*]])
; CHECK-NEXT:    [[PTR:%.*]] = call i1* @lookup_bit(i32* noalias nofree readnone [[Q]], i32 [[BITNO]])
; CHECK-NEXT:    [[VAL:%.*]] = load i1, i1* [[PTR]], align 1
; CHECK-NEXT:    ret i1 [[VAL]]
;
  %ptr = call i1* @lookup_bit(i32* %q, i32 %bitno)
  %val = load i1, i1* %ptr
  ret i1 %val
}


define i32 @nc1(i32* %q, i32* %p, i1 %b) {
; CHECK-LABEL: define {{[^@]+}}@nc1
; CHECK-SAME: (i32* nofree [[Q:%.*]], i32* nocapture nofree [[P:%.*]], i1 [[B:%.*]])
; CHECK-NEXT:  e:
; CHECK-NEXT:    br label [[L:%.*]]
; CHECK:       l:
; CHECK-NEXT:    [[X:%.*]] = phi i32* [ [[P]], [[E:%.*]] ]
; CHECK-NEXT:    [[Y:%.*]] = phi i32* [ [[Q]], [[E]] ]
; CHECK-NEXT:    [[TMP:%.*]] = bitcast i32* [[X]] to i32*
; CHECK-NEXT:    [[TMP2:%.*]] = select i1 [[B]], i32* [[TMP]], i32* [[Y]]
; CHECK-NEXT:    [[VAL:%.*]] = load i32, i32* [[TMP2]], align 4
; CHECK-NEXT:    store i32 0, i32* [[TMP]], align 4
; CHECK-NEXT:    store i32* [[Y]], i32** @g, align 8
; CHECK-NEXT:    ret i32 [[VAL]]
;
e:
  br label %l
l:
  %x = phi i32* [ %p, %e ]
  %y = phi i32* [ %q, %e ]
  %tmp = bitcast i32* %x to i32*		; <i32*> [#uses=2]
  %tmp2 = select i1 %b, i32* %tmp, i32* %y
  %val = load i32, i32* %tmp2		; <i32> [#uses=1]
  store i32 0, i32* %tmp
  store i32* %y, i32** @g
  ret i32 %val
}

define i32 @nc1_addrspace(i32* %q, i32 addrspace(1)* %p, i1 %b) {
; CHECK-LABEL: define {{[^@]+}}@nc1_addrspace
; CHECK-SAME: (i32* nofree [[Q:%.*]], i32 addrspace(1)* nocapture nofree [[P:%.*]], i1 [[B:%.*]])
; CHECK-NEXT:  e:
; CHECK-NEXT:    br label [[L:%.*]]
; CHECK:       l:
; CHECK-NEXT:    [[X:%.*]] = phi i32 addrspace(1)* [ [[P]], [[E:%.*]] ]
; CHECK-NEXT:    [[Y:%.*]] = phi i32* [ [[Q]], [[E]] ]
; CHECK-NEXT:    [[TMP:%.*]] = addrspacecast i32 addrspace(1)* [[X]] to i32*
; CHECK-NEXT:    [[TMP2:%.*]] = select i1 [[B]], i32* [[TMP]], i32* [[Y]]
; CHECK-NEXT:    [[VAL:%.*]] = load i32, i32* [[TMP2]], align 4
; CHECK-NEXT:    store i32 0, i32* [[TMP]], align 4
; CHECK-NEXT:    store i32* [[Y]], i32** @g, align 8
; CHECK-NEXT:    ret i32 [[VAL]]
;
e:
  br label %l
l:
  %x = phi i32 addrspace(1)* [ %p, %e ]
  %y = phi i32* [ %q, %e ]
  %tmp = addrspacecast i32 addrspace(1)* %x to i32*		; <i32*> [#uses=2]
  %tmp2 = select i1 %b, i32* %tmp, i32* %y
  %val = load i32, i32* %tmp2		; <i32> [#uses=1]
  store i32 0, i32* %tmp
  store i32* %y, i32** @g
  ret i32 %val
}

define void @nc2(i32* %p, i32* %q) {
; CHECK-LABEL: define {{[^@]+}}@nc2
; CHECK-SAME: (i32* nocapture nofree [[P:%.*]], i32* nofree [[Q:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = call i32 @nc1(i32* nofree [[Q]], i32* nocapture nofree [[P]], i1 false)
; CHECK-NEXT:    ret void
;
  %1 = call i32 @nc1(i32* %q, i32* %p, i1 0)		; <i32> [#uses=0]
  ret void
}


define void @nc3(void ()* %p) {
; CHECK-LABEL: define {{[^@]+}}@nc3
; CHECK-SAME: (void ()* nocapture nofree nonnull [[P:%.*]])
; CHECK-NEXT:    call void [[P]]()
; CHECK-NEXT:    ret void
;
  call void %p()
  ret void
}

; The following test is tricky because improvements to AAIsDead can cause the call to be removed.
; FIXME: readonly and nocapture missing on the pointer.
declare void @external(i8* readonly) nounwind argmemonly
define void @nc4(i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@nc4
; CHECK-SAME: (i8* [[P:%.*]])
; CHECK-NEXT:    call void @external(i8* readonly [[P]])
; CHECK-NEXT:    ret void
;
  call void @external(i8* %p)
  ret void
}

define void @nc5(void (i8*)* %f, i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@nc5
; CHECK-SAME: (void (i8*)* nocapture nofree nonnull [[F:%.*]], i8* nocapture [[P:%.*]])
; CHECK-NEXT:    call void [[F]](i8* nocapture [[P]])
; CHECK-NEXT:    ret void
;
  call void %f(i8* %p) readonly nounwind
  call void %f(i8* nocapture %p)
  ret void
}

; It would be acceptable to add readnone to %y1_1 and %y1_2.
define void @test1_1(i8* %x1_1, i8* %y1_1, i1 %c) {
; CHECK-LABEL: define {{[^@]+}}@test1_1
; CHECK-SAME: (i8* nocapture nofree readnone [[X1_1:%.*]], i8* nocapture nofree readnone [[Y1_1:%.*]], i1 [[C:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = call i8* @test1_2(i8* noalias nocapture nofree readnone undef, i8* noalias nofree readnone "no-capture-maybe-returned" [[Y1_1]], i1 [[C]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    ret void
;
  call i8* @test1_2(i8* %x1_1, i8* %y1_1, i1 %c)
  store i32* null, i32** @g
  ret void
}

define i8* @test1_2(i8* %x1_2, i8* %y1_2, i1 %c) {
; CHECK-LABEL: define {{[^@]+}}@test1_2
; CHECK-SAME: (i8* nocapture nofree readnone [[X1_2:%.*]], i8* nofree readnone returned "no-capture-maybe-returned" [[Y1_2:%.*]], i1 [[C:%.*]])
; CHECK-NEXT:    br i1 [[C]], label [[T:%.*]], label [[F:%.*]]
; CHECK:       t:
; CHECK-NEXT:    call void @test1_1(i8* noalias nocapture nofree readnone undef, i8* noalias nocapture nofree readnone [[Y1_2]], i1 [[C]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    br label [[F]]
; CHECK:       f:
; CHECK-NEXT:    ret i8* [[Y1_2]]
;
  br i1 %c, label %t, label %f
t:
  call void @test1_1(i8* %x1_2, i8* %y1_2, i1 %c)
  store i32* null, i32** @g
  br label %f
f:
  ret i8* %y1_2
}

define void @test2(i8* %x2) {
; CHECK-LABEL: define {{[^@]+}}@test2
; CHECK-SAME: (i8* nocapture nofree readnone [[X2:%.*]])
; CHECK-NEXT:    unreachable
;
  call void @test2(i8* %x2)
  store i32* null, i32** @g
  ret void
}

define void @test3(i8* %x3, i8* %y3, i8* %z3) {
; CHECK-LABEL: define {{[^@]+}}@test3
; CHECK-SAME: (i8* nocapture nofree readnone [[X3:%.*]], i8* nocapture nofree readnone [[Y3:%.*]], i8* nocapture nofree readnone [[Z3:%.*]])
; CHECK-NEXT:    unreachable
;
  call void @test3(i8* %z3, i8* %y3, i8* %x3)
  store i32* null, i32** @g
  ret void
}

define void @test4_1(i8* %x4_1, i1 %c) {
; CHECK-LABEL: define {{[^@]+}}@test4_1
; CHECK-SAME: (i8* nocapture nofree readnone [[X4_1:%.*]], i1 [[C:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = call i8* @test4_2(i8* noalias nocapture nofree readnone undef, i8* noalias nofree readnone "no-capture-maybe-returned" [[X4_1]], i8* noalias nocapture nofree readnone undef, i1 [[C]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    ret void
;
  call i8* @test4_2(i8* %x4_1, i8* %x4_1, i8* %x4_1, i1 %c)
  store i32* null, i32** @g
  ret void
}

define i8* @test4_2(i8* %x4_2, i8* %y4_2, i8* %z4_2, i1 %c) {
; CHECK-LABEL: define {{[^@]+}}@test4_2
; CHECK-SAME: (i8* nocapture nofree readnone [[X4_2:%.*]], i8* nofree readnone returned "no-capture-maybe-returned" [[Y4_2:%.*]], i8* nocapture nofree readnone [[Z4_2:%.*]], i1 [[C:%.*]])
; CHECK-NEXT:    br i1 [[C]], label [[T:%.*]], label [[F:%.*]]
; CHECK:       t:
; CHECK-NEXT:    call void @test4_1(i8* noalias nocapture nofree readnone align 536870912 null, i1 [[C]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    br label [[F]]
; CHECK:       f:
; CHECK-NEXT:    ret i8* [[Y4_2]]
;
  br i1 %c, label %t, label %f
t:
  call void @test4_1(i8* null, i1 %c)
  store i32* null, i32** @g
  br label %f
f:
  ret i8* %y4_2
}

declare i8* @test5_1(i8* %x5_1)

define void @test5_2(i8* %x5_2) {
; CHECK-LABEL: define {{[^@]+}}@test5_2
; CHECK-SAME: (i8* [[X5_2:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = call i8* @test5_1(i8* [[X5_2]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    ret void
;
  call i8* @test5_1(i8* %x5_2)
  store i32* null, i32** @g
  ret void
}

declare void @test6_1(i8* %x6_1, i8* nocapture %y6_1, ...)

define void @test6_2(i8* %x6_2, i8* %y6_2, i8* %z6_2) {
; CHECK-LABEL: define {{[^@]+}}@test6_2
; CHECK-SAME: (i8* [[X6_2:%.*]], i8* nocapture [[Y6_2:%.*]], i8* [[Z6_2:%.*]])
; CHECK-NEXT:    call void (i8*, i8*, ...) @test6_1(i8* [[X6_2]], i8* nocapture [[Y6_2]], i8* [[Z6_2]])
; CHECK-NEXT:    store i32* null, i32** @g, align 8
; CHECK-NEXT:    ret void
;
  call void (i8*, i8*, ...) @test6_1(i8* %x6_2, i8* %y6_2, i8* %z6_2)
  store i32* null, i32** @g
  ret void
}

define void @test_cmpxchg(i32* %p) {
; CHECK-LABEL: define {{[^@]+}}@test_cmpxchg
; CHECK-SAME: (i32* nocapture nofree nonnull dereferenceable(4) [[P:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = cmpxchg i32* [[P]], i32 0, i32 1 acquire monotonic
; CHECK-NEXT:    ret void
;
  cmpxchg i32* %p, i32 0, i32 1 acquire monotonic
  ret void
}

define void @test_cmpxchg_ptr(i32** %p, i32* %q) {
; CHECK-LABEL: define {{[^@]+}}@test_cmpxchg_ptr
; CHECK-SAME: (i32** nocapture nofree nonnull dereferenceable(8) [[P:%.*]], i32* nofree [[Q:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = cmpxchg i32** [[P]], i32* null, i32* [[Q]] acquire monotonic
; CHECK-NEXT:    ret void
;
  cmpxchg i32** %p, i32* null, i32* %q acquire monotonic
  ret void
}

define void @test_atomicrmw(i32* %p) {
; CHECK-LABEL: define {{[^@]+}}@test_atomicrmw
; CHECK-SAME: (i32* nocapture nofree nonnull dereferenceable(4) [[P:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = atomicrmw add i32* [[P]], i32 1 seq_cst
; CHECK-NEXT:    ret void
;
  atomicrmw add i32* %p, i32 1 seq_cst
  ret void
}

define void @test_volatile(i32* %x) {
; CHECK-LABEL: define {{[^@]+}}@test_volatile
; CHECK-SAME: (i32* nofree align 4 [[X:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr i32, i32* [[X]], i64 1
; CHECK-NEXT:    store volatile i32 0, i32* [[GEP]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %gep = getelementptr i32, i32* %x, i64 1
  store volatile i32 0, i32* %gep, align 4
  ret void
}

define void @nocaptureLaunder(i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@nocaptureLaunder
; CHECK-SAME: (i8* nocapture [[P:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[B:%.*]] = call i8* @llvm.launder.invariant.group.p0i8(i8* [[P]])
; CHECK-NEXT:    store i8 42, i8* [[B]], align 1
; CHECK-NEXT:    ret void
;
entry:
  %b = call i8* @llvm.launder.invariant.group.p0i8(i8* %p)
  store i8 42, i8* %b
  ret void
}

@g2 = global i8* null
define void @captureLaunder(i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@captureLaunder
; CHECK-SAME: (i8* [[P:%.*]])
; CHECK-NEXT:    [[B:%.*]] = call i8* @llvm.launder.invariant.group.p0i8(i8* [[P]])
; CHECK-NEXT:    store i8* [[B]], i8** @g2, align 8
; CHECK-NEXT:    ret void
;
  %b = call i8* @llvm.launder.invariant.group.p0i8(i8* %p)
  store i8* %b, i8** @g2
  ret void
}

define void @nocaptureStrip(i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@nocaptureStrip
; CHECK-SAME: (i8* nocapture writeonly [[P:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[B:%.*]] = call i8* @llvm.strip.invariant.group.p0i8(i8* noalias readnone [[P]])
; CHECK-NEXT:    store i8 42, i8* [[B]], align 1
; CHECK-NEXT:    ret void
;
entry:
  %b = call i8* @llvm.strip.invariant.group.p0i8(i8* %p)
  store i8 42, i8* %b
  ret void
}

@g3 = global i8* null
define void @captureStrip(i8* %p) {
; CHECK-LABEL: define {{[^@]+}}@captureStrip
; CHECK-SAME: (i8* writeonly [[P:%.*]])
; CHECK-NEXT:    [[B:%.*]] = call i8* @llvm.strip.invariant.group.p0i8(i8* noalias readnone [[P]])
; CHECK-NEXT:    store i8* [[B]], i8** @g3, align 8
; CHECK-NEXT:    ret void
;
  %b = call i8* @llvm.strip.invariant.group.p0i8(i8* %p)
  store i8* %b, i8** @g3
  ret void
}

define i1 @captureICmp(i32* %x) {
; CHECK-LABEL: define {{[^@]+}}@captureICmp
; CHECK-SAME: (i32* nofree readnone [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = icmp eq i32* [[X]], null
; CHECK-NEXT:    ret i1 [[TMP1]]
;
  %1 = icmp eq i32* %x, null
  ret i1 %1
}

define i1 @captureICmpRev(i32* %x) {
; CHECK-LABEL: define {{[^@]+}}@captureICmpRev
; CHECK-SAME: (i32* nofree readnone [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = icmp eq i32* null, [[X]]
; CHECK-NEXT:    ret i1 [[TMP1]]
;
  %1 = icmp eq i32* null, %x
  ret i1 %1
}

define i1 @nocaptureInboundsGEPICmp(i32* %x) {
; CHECK-LABEL: define {{[^@]+}}@nocaptureInboundsGEPICmp
; CHECK-SAME: (i32* nocapture nofree readnone [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds i32, i32* [[X]], i32 5
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast i32* [[TMP1]] to i8*
; CHECK-NEXT:    [[TMP3:%.*]] = icmp eq i8* [[TMP2]], null
; CHECK-NEXT:    ret i1 [[TMP3]]
;
  %1 = getelementptr inbounds i32, i32* %x, i32 5
  %2 = bitcast i32* %1 to i8*
  %3 = icmp eq i8* %2, null
  ret i1 %3
}

define i1 @nocaptureInboundsGEPICmpRev(i32* %x) {
; CHECK-LABEL: define {{[^@]+}}@nocaptureInboundsGEPICmpRev
; CHECK-SAME: (i32* nocapture nofree readnone [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds i32, i32* [[X]], i32 5
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast i32* [[TMP1]] to i8*
; CHECK-NEXT:    [[TMP3:%.*]] = icmp eq i8* null, [[TMP2]]
; CHECK-NEXT:    ret i1 [[TMP3]]
;
  %1 = getelementptr inbounds i32, i32* %x, i32 5
  %2 = bitcast i32* %1 to i8*
  %3 = icmp eq i8* null, %2
  ret i1 %3
}

define i1 @nocaptureDereferenceableOrNullICmp(i32* dereferenceable_or_null(4) %x) {
; CHECK-LABEL: define {{[^@]+}}@nocaptureDereferenceableOrNullICmp
; CHECK-SAME: (i32* nocapture nofree readnone dereferenceable_or_null(4) [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast i32* [[X]] to i8*
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i8* [[TMP1]], null
; CHECK-NEXT:    ret i1 [[TMP2]]
;
  %1 = bitcast i32* %x to i8*
  %2 = icmp eq i8* %1, null
  ret i1 %2
}

define i1 @captureDereferenceableOrNullICmp(i32* dereferenceable_or_null(4) %x) null_pointer_is_valid {
; CHECK-LABEL: define {{[^@]+}}@captureDereferenceableOrNullICmp
; CHECK-SAME: (i32* nofree readnone dereferenceable_or_null(4) [[X:%.*]])
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast i32* [[X]] to i8*
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq i8* [[TMP1]], null
; CHECK-NEXT:    ret i1 [[TMP2]]
;
  %1 = bitcast i32* %x to i8*
  %2 = icmp eq i8* %1, null
  ret i1 %2
}

declare void @unknown(i8*)
; We know that 'null' in AS 0 does not alias anything and cannot be captured. Though the latter is not qurried -> derived atm.
define void @test_callsite() {
; CHECK-LABEL: define {{[^@]+}}@test_callsite()
; CHECK-NEXT:  entry:
; CHECK-NEXT:    call void @unknown(i8* noalias nocapture align 536870912 null)
; CHECK-NEXT:    ret void
;
entry:
  call void @unknown(i8* null)
  ret void
}

declare i8* @unknownpi8pi8(i8*,i8* returned)
define i8* @test_returned1(i8* %A, i8* returned %B) nounwind readonly {
; CHECK-LABEL: define {{[^@]+}}@test_returned1
; CHECK-SAME: (i8* nocapture readonly [[A:%.*]], i8* readonly returned [[B:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[P:%.*]] = call i8* @unknownpi8pi8(i8* [[A]], i8* [[B]])
; CHECK-NEXT:    ret i8* [[P]]
;
entry:
  %p = call i8* @unknownpi8pi8(i8* %A, i8* %B)
  ret i8* %p
}

define i8* @test_returned2(i8* %A, i8* %B) {
; CHECK-LABEL: define {{[^@]+}}@test_returned2
; CHECK-SAME: (i8* nocapture readonly [[A:%.*]], i8* readonly returned [[B:%.*]])
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[P:%.*]] = call i8* @unknownpi8pi8(i8* readonly [[A]], i8* readonly [[B]])
; CHECK-NEXT:    ret i8* [[P]]
;
entry:
  %p = call i8* @unknownpi8pi8(i8* %A, i8* %B) nounwind readonly
  ret i8* %p
}

declare i8* @maybe_returned_ptr(i8* readonly %ptr) readonly nounwind
declare i8 @maybe_returned_val(i8* %ptr) readonly nounwind
declare void @val_use(i8 %ptr) readonly nounwind

; FIXME: Both pointers should be nocapture
define void @ptr_uses(i8* %ptr, i8* %wptr) {
; CHECK-LABEL: define {{[^@]+}}@ptr_uses
; CHECK-SAME: (i8* [[PTR:%.*]], i8* nocapture nonnull writeonly dereferenceable(1) [[WPTR:%.*]])
; CHECK-NEXT:    store i8 0, i8* [[WPTR]], align 1
; CHECK-NEXT:    ret void
;
  %call_ptr = call i8* @maybe_returned_ptr(i8* %ptr)
  %call_val = call i8 @maybe_returned_val(i8* %call_ptr)
  call void @val_use(i8 %call_val)
  store i8 0, i8* %wptr
  ret void
}

declare i8* @llvm.launder.invariant.group.p0i8(i8*)
declare i8* @llvm.strip.invariant.group.p0i8(i8*)
