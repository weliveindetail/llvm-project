; REQUIRES: plugins, examples
; UNSUPPORTED: linked-bye, target={{.*windows.*}}
; Plugins are currently broken on AIX, at least in the CI.
; XFAIL: target={{.*}}-aix{{.*}}

;; Pass-plugins are part of the ThinLTO cache key.
; RUN: rm -rf %t.cache
; RUN: opt -module-hash -module-summary %s -o %t.bc

; RUN: llvm-lto2 run -o %t.o %t.bc -cache-dir %t.cache -r=%t.bc,globalfunc,plx
; RUN: llvm-lto2 run -o %t.o %t.bc -cache-dir %t.cache -r=%t.bc,globalfunc,plx -load-pass-plugin=%llvmshlibdir/Bye%pluginext
; RUN: ls %t.cache | count 2

;; The same plugin hits the existing entry.
; RUN: llvm-lto2 run -o %t.o %t.bc -cache-dir %t.cache -r=%t.bc,globalfunc,plx -load-pass-plugin=%llvmshlibdir/Bye%pluginext
; RUN: ls %t.cache | count 2

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @globalfunc() {
entry:
  ret void
}
