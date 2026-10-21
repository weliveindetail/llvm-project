// RUN: %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -O2 -fpass-plugin-arg=Bye,-wave-goodbye 2>&1 | FileCheck %s --check-prefix=WAVE
// RUN: %clang_cc1 -S < %s -fpass-plugin=%llvmshlibdir/Bye%pluginext -fpass-plugin-arg=Bye,-last-words | FileCheck %s --check-prefix=LAST
/// A plugin receives all of its arguments. They split at the first comma only,
/// so the value may contain commas.
// RUN: %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -O2 -fpass-plugin-arg=Bye,-wave-goodbye -fpass-plugin-arg=Bye,-bye-greeting=See,you 2>&1 | FileCheck %s --check-prefix=BOTH
/// The driver forwards the flag.
// RUN: %clang -S %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -O2 -fpass-plugin-arg=Bye,-wave-goodbye -fpass-plugin-arg=Bye,-bye-greeting=See,you 2>&1 | FileCheck %s --check-prefix=BOTH
// RUN: not %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -fpass-plugin-arg=Bye 2>&1 | FileCheck %s --check-prefix=NOCOMMA
// RUN: not %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -fpass-plugin-arg=Nope,-x 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -fpass-plugin-arg=Bye,-no-such-bye-option 2>&1 | FileCheck %s --check-prefix=REJECTED
/// A plugin that failed to load is reported only once.
// RUN: not %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%t.missing%pluginext -fpass-plugin-arg=Bye,-wave-goodbye 2>&1 | FileCheck %s --check-prefix=MISSING
/// Without arguments, loading a plugin twice is no error.
// RUN: %clang_cc1 -S < %s -o /dev/null -fpass-plugin=%llvmshlibdir/Bye%pluginext -fpass-plugin=%llvmshlibdir/Bye%pluginext
// REQUIRES: plugins, llvm-examples
// UNSUPPORTED: target={{.*windows.*}}
// Plugins are currently broken on AIX, at least in the CI.
// XFAIL: target={{.*}}-aix{{.*}}
// WAVE: Bye: f
// LAST: CodeGen Bye
// BOTH:      Bye: f
// BOTH-NEXT: See,you: f
// NOCOMMA: error: expected <plugin>,<arg> in 'Bye'{{$}}
// UNKNOWN: error: no pass plugin named 'Nope' is loaded, in 'Nope,-x'
// REJECTED: error: Bye: Unknown command line argument '-no-such-bye-option'
// MISSING:     error: unable to load plugin
// MISSING-NOT: error:

int f(int x) {
  return x;
}
