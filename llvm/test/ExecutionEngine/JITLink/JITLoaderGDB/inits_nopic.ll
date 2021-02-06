; ModuleID = 'inits.c'
source_filename = "inits.c"
target triple = "x86_64-pc-linux-gnu"

@.str = private unnamed_addr constant [12 x i8] c"Foo::Foo()\0A\00", align 1
@.str.1 = private unnamed_addr constant [12 x i8] c"Foo::foo()\0A\00", align 1
@.str.2 = private unnamed_addr constant [13 x i8] c"Foo::~Foo()\0A\00", align 1

; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @FooCtor() #0 !dbg !7 {
  %1 = call i32 @puts(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str, i32 0, i32 0)), !dbg !10
  ret void, !dbg !11
}

declare dso_local i32 @puts(i8*) #1

; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @FooFoo() #0 !dbg !12 {
  %1 = call i32 @puts(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.1, i32 0, i32 0)), !dbg !13
  ret void, !dbg !14
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local void @FooDtor() #0 !dbg !15 {
  %1 = call i32 @puts(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.2, i32 0, i32 0)), !dbg !16
  ret void, !dbg !17
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @main(i32, i8**) #0 !dbg !18 {
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  %5 = alloca i8**, align 8
  store i32 0, i32* %3, align 4
  store i32 %0, i32* %4, align 4
  call void @llvm.dbg.declare(metadata i32* %4, metadata !25, metadata !DIExpression()), !dbg !26
  store i8** %1, i8*** %5, align 8
  call void @llvm.dbg.declare(metadata i8*** %5, metadata !27, metadata !DIExpression()), !dbg !28
  call void @FooCtor(), !dbg !29
  call void @FooFoo(), !dbg !30
  call void @FooDtor(), !dbg !31
  ret i32 0, !dbg !32
}

; Function Attrs: nounwind readnone speculatable
declare void @llvm.dbg.declare(metadata, metadata, metadata) #2

attributes #0 = { noinline nounwind optnone uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #2 = { nounwind readnone speculatable }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4, !5}
!llvm.ident = !{!6}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "clang version 7.0.1-8+deb10u2 (tags/RELEASE_701/final)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !2)
!1 = !DIFile(filename: "inits.c", directory: "/workspaces/llvm-project/llvm/test/ExecutionEngine/JITLink/JITLoaderGDB")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"wchar_size", i32 4}
!6 = !{!"clang version 7.0.1-8+deb10u2 (tags/RELEASE_701/final)"}
!7 = distinct !DISubprogram(name: "FooCtor", scope: !1, file: !1, line: 4, type: !8, isLocal: false, isDefinition: true, scopeLine: 4, isOptimized: false, unit: !0, retainedNodes: !2)
!8 = !DISubroutineType(types: !9)
!9 = !{null}
!10 = !DILocation(line: 5, column: 3, scope: !7)
!11 = !DILocation(line: 6, column: 1, scope: !7)
!12 = distinct !DISubprogram(name: "FooFoo", scope: !1, file: !1, line: 8, type: !8, isLocal: false, isDefinition: true, scopeLine: 8, isOptimized: false, unit: !0, retainedNodes: !2)
!13 = !DILocation(line: 9, column: 3, scope: !12)
!14 = !DILocation(line: 10, column: 1, scope: !12)
!15 = distinct !DISubprogram(name: "FooDtor", scope: !1, file: !1, line: 12, type: !8, isLocal: false, isDefinition: true, scopeLine: 12, isOptimized: false, unit: !0, retainedNodes: !2)
!16 = !DILocation(line: 13, column: 3, scope: !15)
!17 = !DILocation(line: 14, column: 1, scope: !15)
!18 = distinct !DISubprogram(name: "main", scope: !1, file: !1, line: 16, type: !19, isLocal: false, isDefinition: true, scopeLine: 16, flags: DIFlagPrototyped, isOptimized: false, unit: !0, retainedNodes: !2)
!19 = !DISubroutineType(types: !20)
!20 = !{!21, !21, !22}
!21 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!22 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !23, size: 64)
!23 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !24, size: 64)
!24 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_signed_char)
!25 = !DILocalVariable(name: "argc", arg: 1, scope: !18, file: !1, line: 16, type: !21)
!26 = !DILocation(line: 16, column: 14, scope: !18)
!27 = !DILocalVariable(name: "argv", arg: 2, scope: !18, file: !1, line: 16, type: !22)
!28 = !DILocation(line: 16, column: 26, scope: !18)
!29 = !DILocation(line: 17, column: 3, scope: !18)
!30 = !DILocation(line: 18, column: 3, scope: !18)
!31 = !DILocation(line: 19, column: 3, scope: !18)
!32 = !DILocation(line: 20, column: 3, scope: !18)
