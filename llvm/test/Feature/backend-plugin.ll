; RUN: split-file %s %t
; RUN: llc -load-pass-plugin %llvmshlibdir/BackendPluginAArch64%pluginext %t/main.ll -o - | FileCheck %s --check-prefix=CHECK-REPLACE
; RUN: llc -load-pass-plugin %llvmshlibdir/BackendPluginAArch64%pluginext %t/probe.ll -o - | FileCheck %s --check-prefix=CHECK-PROBE
; REQUIRES: native, system-linux, llvm-dylib, aarch64-registered-target

;--- main.ll

; BackendPluginAArch64 embeds its own, statically-linked, fully isolated copy
; of the AArch64 backend and unconditionally takes over code generation via
; PreCodeGenCallback, replacing whatever the host's native target would
; otherwise produce.
; CHECK-REPLACE: // @main
define void @main() {
  ret void
}

;--- probe.ll

; BackendPluginAArch64 also embeds its own, statically-linked, fully isolated
; copy of APFloat (see AArch64PreCodeGenCallback.cpp), separate from the
; host's. apfloat_probe's ConstantFP is built by the host while parsing this
; file, so it carries a pointer to the *host's* APFloat::IEEEdouble() static,
; not the plugin's own. Several APFloat APIs identify a format by comparing
; its fltSemantics address rather than its value, so this address mismatch
; is real despite both sides describing an ordinary IEEE double -- letting
; codegen run on it crashes deep inside APFloat (see the plugin's comments
; for where). This part only demonstrates the mismatch itself.
; CHECK-PROBE: apfloat_probe semantics address is DIFFERENT from this plugin's own APFloat::IEEEdouble()
@apfloat_probe = global double 1.0
