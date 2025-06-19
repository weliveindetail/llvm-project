// REQUIRES: pass-plugins

// RUN: %clang -fpass-plugin=%pass_plugin_reference -Xclang -load -Xclang %pass_plugin_reference -mllvm -wave-goodbye -S -emit-llvm -Xclang -fdebug-pass-manager %s -o /dev/null 2>&1 | FileCheck %s

// CHECK: Running pass: TestModulePass on [module]

int main() { return 0; }

// FIXME Options don't work without the extra -load
// RUN: not %clang -fpass-plugin=%pass_plugin_reference -mllvm -wave-goodbye -S -emit-llvm -Xclang -fdebug-pass-manager %s -o /dev/null 2>&1 | FileCheck --check-prefix=NEEDS-LOAD %s

// NEEDS-LOAD: Unknown command line argument
