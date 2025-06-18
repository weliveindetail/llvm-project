// REQUIRES: pass-plugins

// RUN: %clang -fpass-plugin=%pass_plugin_reference -S -emit-llvm -Xclang -fdebug-pass-manager %s -o /dev/null 2>&1 | FileCheck %s

// CHECK: Running pass: TestModulePass on [module]

int main() { return 0; }
