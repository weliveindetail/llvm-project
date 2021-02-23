; REQUIRES: target-x86_64
; XFAIL: system-windows

; RUN: lli --jit-kind=mcjit --dyld=runtime-dyld %s | FileCheck %s
; RUN: lli --jit-kind=orc-lazy --per-module-lazy --dyld=jitlink %s | FileCheck %s

; CHECK: Reading __jit_debug_descriptor at 0x{{.*}}
; CHECK: Version: 1
; CHECK: Action: JIT_REGISTER_FN
; CHECK:       Entry               Symbol File             Size  Previous Entry
; CHECK: [ 0]  0x{{.*}}            0x{{.*}}              {{.*}}  0x0000000000000000

source_filename = "dump-jit-debug-descriptor.c"
target triple = "x86_64-pc-linux-gnu"

%struct.jit_descriptor = type { i32, i32, %struct.jit_code_entry*, %struct.jit_code_entry* }
%struct.jit_code_entry = type { %struct.jit_code_entry*, %struct.jit_code_entry*, i8*, i64 }

@.str = private unnamed_addr constant [13 x i8] c"JIT_NOACTION\00", align 1
@.str.1 = private unnamed_addr constant [16 x i8] c"JIT_REGISTER_FN\00", align 1
@.str.2 = private unnamed_addr constant [18 x i8] c"JIT_UNREGISTER_FN\00", align 1
@.str.3 = private unnamed_addr constant [22 x i8] c"<invalid action_flag>\00", align 1
@.str.4 = private unnamed_addr constant [45 x i8] c"Reading __jit_debug_descriptor at 0x%016lX\0A\0A\00", align 1
@.str.5 = private unnamed_addr constant [13 x i8] c"Version: %d\0A\00", align 1
@.str.6 = private unnamed_addr constant [13 x i8] c"Action: %s\0A\0A\00", align 1
@.str.7 = private unnamed_addr constant [24 x i8] c"%11s  %24s  %15s  %14s\0A\00", align 1
@.str.8 = private unnamed_addr constant [43 x i8] c"[%2d]  0x%016lX  0x%016lX  %8ld  0x%016lX\0A\00", align 1
@.str.9 = private unnamed_addr constant [6 x i8] c"Entry\00", align 1
@.str.10 = private unnamed_addr constant [12 x i8] c"Symbol File\00", align 1
@.str.11 = private unnamed_addr constant [5 x i8] c"Size\00", align 1
@.str.12 = private unnamed_addr constant [15 x i8] c"Previous Entry\00", align 1
@__jit_debug_descriptor = external global %struct.jit_descriptor, align 8

declare i32 @printf(i8*, ...)
declare void @llvm.dbg.declare(metadata, metadata, metadata)

; Function Attrs: noinline nounwind optnone uwtable
define i8* @actionFlagToStr(i32) !dbg !12 {
  %2 = alloca i8*, align 8
  %3 = alloca i32, align 4
  store i32 %0, i32* %3, align 4
  call void @llvm.dbg.declare(metadata i32* %3, metadata !23, metadata !DIExpression()), !dbg !24
  %4 = load i32, i32* %3, align 4, !dbg !25
  switch i32 %4, label %8 [
    i32 0, label %5
    i32 1, label %6
    i32 2, label %7
  ], !dbg !26

; <label>:5:                                      ; preds = %1
  store i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str, i32 0, i32 0), i8** %2, align 8, !dbg !27
  br label %9, !dbg !27

; <label>:6:                                      ; preds = %1
  store i8* getelementptr inbounds ([16 x i8], [16 x i8]* @.str.1, i32 0, i32 0), i8** %2, align 8, !dbg !29
  br label %9, !dbg !29

; <label>:7:                                      ; preds = %1
  store i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.2, i32 0, i32 0), i8** %2, align 8, !dbg !30
  br label %9, !dbg !30

; <label>:8:                                      ; preds = %1
  store i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.3, i32 0, i32 0), i8** %2, align 8, !dbg !31
  br label %9, !dbg !31

; <label>:9:                                      ; preds = %8, %7, %6, %5
  %10 = load i8*, i8** %2, align 8, !dbg !32
  ret i8* %10, !dbg !32
}

define i32 @main() !dbg !33 {
  %1 = alloca i32, align 4
  %2 = alloca i8*, align 8
  %3 = alloca i8*, align 8
  %4 = alloca i32, align 4
  %5 = alloca %struct.jit_code_entry*, align 8
  store i32 0, i32* %1, align 4
  %6 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([45 x i8], [45 x i8]* @.str.4, i32 0, i32 0), i64 ptrtoint (%struct.jit_descriptor* @__jit_debug_descriptor to i64)), !dbg !37
  %7 = load i32, i32* getelementptr inbounds (%struct.jit_descriptor, %struct.jit_descriptor* @__jit_debug_descriptor, i32 0, i32 0), align 8, !dbg !38
  %8 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.5, i32 0, i32 0), i32 %7), !dbg !39
  %9 = load i32, i32* getelementptr inbounds (%struct.jit_descriptor, %struct.jit_descriptor* @__jit_debug_descriptor, i32 0, i32 1), align 4, !dbg !40
  %10 = call i8* @actionFlagToStr(i32 %9), !dbg !41
  %11 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.6, i32 0, i32 0), i8* %10), !dbg !42
  call void @llvm.dbg.declare(metadata i8** %2, metadata !43, metadata !DIExpression()), !dbg !44
  store i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.7, i32 0, i32 0), i8** %2, align 8, !dbg !44
  call void @llvm.dbg.declare(metadata i8** %3, metadata !45, metadata !DIExpression()), !dbg !46
  store i8* getelementptr inbounds ([43 x i8], [43 x i8]* @.str.8, i32 0, i32 0), i8** %3, align 8, !dbg !46
  call void @llvm.dbg.declare(metadata i32* %4, metadata !47, metadata !DIExpression()), !dbg !48
  store i32 0, i32* %4, align 4, !dbg !48
  call void @llvm.dbg.declare(metadata %struct.jit_code_entry** %5, metadata !49, metadata !DIExpression()), !dbg !59
  %12 = load %struct.jit_code_entry*, %struct.jit_code_entry** getelementptr inbounds (%struct.jit_descriptor, %struct.jit_descriptor* @__jit_debug_descriptor, i32 0, i32 3), align 8, !dbg !60
  store %struct.jit_code_entry* %12, %struct.jit_code_entry** %5, align 8, !dbg !59
  %13 = load i8*, i8** %2, align 8, !dbg !61
  %14 = call i32 (i8*, ...) @printf(i8* %13, i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str.9, i32 0, i32 0), i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.10, i32 0, i32 0), i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.11, i32 0, i32 0), i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.12, i32 0, i32 0)), !dbg !62
  br label %15, !dbg !63

; <label>:15:                                     ; preds = %18, %0
  %16 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !64
  %17 = icmp ne %struct.jit_code_entry* %16, null, !dbg !63
  br i1 %17, label %18, label %40, !dbg !63

; <label>:18:                                     ; preds = %15
  %19 = load i8*, i8** %3, align 8, !dbg !65
  %20 = load i32, i32* %4, align 4, !dbg !67
  %21 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !68
  %22 = ptrtoint %struct.jit_code_entry* %21 to i64, !dbg !69
  %23 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !70
  %24 = getelementptr inbounds %struct.jit_code_entry, %struct.jit_code_entry* %23, i32 0, i32 2, !dbg !71
  %25 = load i8*, i8** %24, align 8, !dbg !71
  %26 = ptrtoint i8* %25 to i64, !dbg !72
  %27 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !73
  %28 = getelementptr inbounds %struct.jit_code_entry, %struct.jit_code_entry* %27, i32 0, i32 3, !dbg !74
  %29 = load i64, i64* %28, align 8, !dbg !74
  %30 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !75
  %31 = getelementptr inbounds %struct.jit_code_entry, %struct.jit_code_entry* %30, i32 0, i32 1, !dbg !76
  %32 = load %struct.jit_code_entry*, %struct.jit_code_entry** %31, align 8, !dbg !76
  %33 = ptrtoint %struct.jit_code_entry* %32 to i64, !dbg !77
  %34 = call i32 (i8*, ...) @printf(i8* %19, i32 %20, i64 %22, i64 %26, i64 %29, i64 %33), !dbg !78
  %35 = load %struct.jit_code_entry*, %struct.jit_code_entry** %5, align 8, !dbg !79
  %36 = getelementptr inbounds %struct.jit_code_entry, %struct.jit_code_entry* %35, i32 0, i32 0, !dbg !80
  %37 = load %struct.jit_code_entry*, %struct.jit_code_entry** %36, align 8, !dbg !80
  store %struct.jit_code_entry* %37, %struct.jit_code_entry** %5, align 8, !dbg !81
  %38 = load i32, i32* %4, align 4, !dbg !82
  %39 = add i32 %38, 1, !dbg !82
  store i32 %39, i32* %4, align 4, !dbg !82
  br label %15, !dbg !63, !llvm.loop !83

; <label>:40:                                     ; preds = %15
  ret i32 0, !dbg !85
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!7, !8, !9, !10}
!llvm.ident = !{!11}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "clang version 7.0.1-8+deb10u2 (tags/RELEASE_701/final)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !2, retainedTypes: !3)
!1 = !DIFile(filename: "dump-jit-debug-descriptor.c", directory: "/workspaces/llvm-project/llvm/test/ExecutionEngine/OrcLazy")
!2 = !{}
!3 = !{!4}
!4 = !DIDerivedType(tag: DW_TAG_typedef, name: "uintptr_t", file: !5, line: 90, baseType: !6)
!5 = !DIFile(filename: "/usr/include/stdint.h", directory: "/workspaces/llvm-project/llvm/test/ExecutionEngine/OrcLazy")
!6 = !DIBasicType(name: "long unsigned int", size: 64, encoding: DW_ATE_unsigned)
!7 = !{i32 2, !"Dwarf Version", i32 4}
!8 = !{i32 2, !"Debug Info Version", i32 3}
!9 = !{i32 1, !"wchar_size", i32 4}
!10 = !{i32 7, !"PIC Level", i32 2}
!11 = !{!"clang version 7.0.1-8+deb10u2 (tags/RELEASE_701/final)"}
!12 = distinct !DISubprogram(name: "actionFlagToStr", scope: !1, file: !1, line: 53, type: !13, isLocal: false, isDefinition: true, scopeLine: 53, flags: DIFlagPrototyped, isOptimized: false, unit: !0, retainedNodes: !2)
!13 = !DISubroutineType(types: !14)
!14 = !{!15, !18}
!15 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !16, size: 64)
!16 = !DIDerivedType(tag: DW_TAG_const_type, baseType: !17)
!17 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_signed_char)
!18 = !DIDerivedType(tag: DW_TAG_typedef, name: "uint32_t", file: !19, line: 26, baseType: !20)
!19 = !DIFile(filename: "/usr/include/x86_64-linux-gnu/bits/stdint-uintn.h", directory: "/workspaces/llvm-project/llvm/test/ExecutionEngine/OrcLazy")
!20 = !DIDerivedType(tag: DW_TAG_typedef, name: "__uint32_t", file: !21, line: 41, baseType: !22)
!21 = !DIFile(filename: "/usr/include/x86_64-linux-gnu/bits/types.h", directory: "/workspaces/llvm-project/llvm/test/ExecutionEngine/OrcLazy")
!22 = !DIBasicType(name: "unsigned int", size: 32, encoding: DW_ATE_unsigned)
!23 = !DILocalVariable(name: "ActionFlag", arg: 1, scope: !12, file: !1, line: 53, type: !18)
!24 = !DILocation(line: 53, column: 38, scope: !12)
!25 = !DILocation(line: 54, column: 11, scope: !12)
!26 = !DILocation(line: 54, column: 3, scope: !12)
!27 = !DILocation(line: 56, column: 5, scope: !28)
!28 = distinct !DILexicalBlock(scope: !12, file: !1, line: 54, column: 23)
!29 = !DILocation(line: 58, column: 5, scope: !28)
!30 = !DILocation(line: 60, column: 5, scope: !28)
!31 = !DILocation(line: 62, column: 3, scope: !12)
!32 = !DILocation(line: 63, column: 1, scope: !12)
!33 = distinct !DISubprogram(name: "main", scope: !1, file: !1, line: 77, type: !34, isLocal: false, isDefinition: true, scopeLine: 77, isOptimized: false, unit: !0, retainedNodes: !2)
!34 = !DISubroutineType(types: !35)
!35 = !{!36}
!36 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!37 = !DILocation(line: 78, column: 3, scope: !33)
!38 = !DILocation(line: 80, column: 50, scope: !33)
!39 = !DILocation(line: 80, column: 3, scope: !33)
!40 = !DILocation(line: 81, column: 67, scope: !33)
!41 = !DILocation(line: 81, column: 28, scope: !33)
!42 = !DILocation(line: 81, column: 3, scope: !33)
!43 = !DILocalVariable(name: "FmtHead", scope: !33, file: !1, line: 83, type: !15)
!44 = !DILocation(line: 83, column: 15, scope: !33)
!45 = !DILocalVariable(name: "FmtRow", scope: !33, file: !1, line: 84, type: !15)
!46 = !DILocation(line: 84, column: 15, scope: !33)
!47 = !DILocalVariable(name: "Idx", scope: !33, file: !1, line: 87, type: !22)
!48 = !DILocation(line: 87, column: 12, scope: !33)
!49 = !DILocalVariable(name: "Entry", scope: !33, file: !1, line: 88, type: !50)
!50 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !51, size: 64)
!51 = distinct !DICompositeType(tag: DW_TAG_structure_type, name: "jit_code_entry", file: !1, line: 34, size: 256, elements: !52)
!52 = !{!53, !54, !55, !56}
!53 = !DIDerivedType(tag: DW_TAG_member, name: "next_entry", scope: !51, file: !1, line: 35, baseType: !50, size: 64)
!54 = !DIDerivedType(tag: DW_TAG_member, name: "prev_entry", scope: !51, file: !1, line: 36, baseType: !50, size: 64, offset: 64)
!55 = !DIDerivedType(tag: DW_TAG_member, name: "symfile_addr", scope: !51, file: !1, line: 37, baseType: !15, size: 64, offset: 128)
!56 = !DIDerivedType(tag: DW_TAG_member, name: "symfile_size", scope: !51, file: !1, line: 38, baseType: !57, size: 64, offset: 192)
!57 = !DIDerivedType(tag: DW_TAG_typedef, name: "uint64_t", file: !19, line: 27, baseType: !58)
!58 = !DIDerivedType(tag: DW_TAG_typedef, name: "__uint64_t", file: !21, line: 44, baseType: !6)
!59 = !DILocation(line: 88, column: 26, scope: !33)
!60 = !DILocation(line: 88, column: 57, scope: !33)
!61 = !DILocation(line: 89, column: 10, scope: !33)
!62 = !DILocation(line: 89, column: 3, scope: !33)
!63 = !DILocation(line: 90, column: 3, scope: !33)
!64 = !DILocation(line: 90, column: 10, scope: !33)
!65 = !DILocation(line: 91, column: 12, scope: !66)
!66 = distinct !DILexicalBlock(scope: !33, file: !1, line: 90, column: 17)
!67 = !DILocation(line: 91, column: 20, scope: !66)
!68 = !DILocation(line: 91, column: 36, scope: !66)
!69 = !DILocation(line: 91, column: 25, scope: !66)
!70 = !DILocation(line: 91, column: 54, scope: !66)
!71 = !DILocation(line: 91, column: 61, scope: !66)
!72 = !DILocation(line: 91, column: 43, scope: !66)
!73 = !DILocation(line: 92, column: 12, scope: !66)
!74 = !DILocation(line: 92, column: 19, scope: !66)
!75 = !DILocation(line: 92, column: 44, scope: !66)
!76 = !DILocation(line: 92, column: 51, scope: !66)
!77 = !DILocation(line: 92, column: 33, scope: !66)
!78 = !DILocation(line: 91, column: 5, scope: !66)
!79 = !DILocation(line: 93, column: 13, scope: !66)
!80 = !DILocation(line: 93, column: 20, scope: !66)
!81 = !DILocation(line: 93, column: 11, scope: !66)
!82 = !DILocation(line: 94, column: 9, scope: !66)
!83 = distinct !{!83, !63, !84}
!84 = !DILocation(line: 95, column: 3, scope: !33)
!85 = !DILocation(line: 97, column: 3, scope: !33)
