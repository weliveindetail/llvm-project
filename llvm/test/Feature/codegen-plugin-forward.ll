; Check that we can forward PreCodeGenCallback to llvm::runCodeGenPipeline()
; REQUIRES: system-linux, llvm-dylib, plugins, examples

; llc calls the plugin hook before it picks a pipeline. runCodeGenPipeline()
; then picks legacy or New PM codegen based on the target.
; RUN: %if x86-registered-target %{ llc -mtriple=x86_64 -load-pass-plugin %llvmshlibdir/Ciao%pluginext \
; RUN:     -plugin-arg=Ciao,forward-codegen %s -o /dev/null 2>&1 | FileCheck %s %}
; RUN: %if aarch64-registered-target %{ llc -mtriple=aarch64 -load-pass-plugin %llvmshlibdir/Ciao%pluginext \
; RUN:     -plugin-arg=Ciao,forward-codegen %s -o /dev/null 2>&1 | FileCheck %s %}
; CHECK: Ciao: forwarding to runCodeGenPipeline

define void @main() {
  ret void
}
