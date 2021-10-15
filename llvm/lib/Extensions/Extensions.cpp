#include "llvm/Passes/PassPlugin.h"

// Fix linker error:
// 		Undefined symbols for architecture x86_64:
// 		  "llvm::DisableABIBreakingChecks", referenced from:
// 		      llvm::VerifyDisableABIBreakingChecks in Extensions.cpp.o
//
// This would usually be accomplished by linking against Support.
// Definition copied from: llvm/lib/Support/ABIBreak.cpp
//
#ifndef _MSC_VER
namespace llvm {

// One of these two variables will be referenced by a symbol defined in
// llvm-config.h. We provide a link-time (or load time for DSO) failure when
// there is a mismatch in the build configuration of the API client and LLVM.
#if LLVM_ENABLE_ABI_BREAKING_CHECKS
int EnableABIBreakingChecks;
#else
int DisableABIBreakingChecks;
#endif

} // end namespace llvm
#endif

#define HANDLE_EXTENSION(Ext)                                                  \
		llvm::PassPluginLibraryInfo get##Ext##PluginInfo();
#include "llvm/Support/Extension.def"


namespace llvm {
	namespace details {
		void extensions_anchor() {
#define HANDLE_EXTENSION(Ext)                                                  \
			static auto Ext = get##Ext##PluginInfo();
#include "llvm/Support/Extension.def"
		}
	}
}
