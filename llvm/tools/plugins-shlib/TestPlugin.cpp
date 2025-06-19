//===- unittests/Passes/TestPlugin.cpp --------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

#include "TestPlugin.h"

using namespace llvm;

static cl::opt<bool> Wave("wave-goodbye", cl::init(false),
                          cl::desc("wave good bye"));

struct TestModulePass : public PassInfoMixin<TestModulePass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM) {
    return PreservedAnalyses::all();
  }

  static void registerCallbacks(PassBuilder &PB) {
    printf("Plugin -wave-goodbye parameter value: %s\n", Wave ? "true" : "false");

    PB.registerPipelineEarlySimplificationEPCallback(
        [](ModulePassManager &MPM, OptimizationLevel Opt, ThinOrFullLTOPhase Phase) {
          fprintf(stderr,
                  "[llvm-py-pass] Adding pass to optimizer pipeline\n");
          MPM.addPass(TestModulePass());
          return true;
        });
  }
};

extern "C" ::llvm::PassPluginLibraryInfo LLVM_ATTRIBUTE_WEAK
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, TEST_PLUGIN_NAME, TEST_PLUGIN_VERSION,
          TestModulePass::registerCallbacks};
}
