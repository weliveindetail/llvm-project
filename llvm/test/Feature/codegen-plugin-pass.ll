; REQUIRES: x86-registered-target || aarch64-registered-target
; REQUIRES: plugins

; Plugins are currently broken on AIX, at least in the CI.
; XFAIL: target={{.*}}-aix{{.*}}

; RUN: llc -load-pass-plugin %llvmshlibdir/CGTestPlugin%pluginext %s -o - | FileCheck %s

; CHECK: CodeGen Test Pass running on main
define void @main() {
  ret void
}
