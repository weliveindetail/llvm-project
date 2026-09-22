# A self-contained plugin fixture for backend-plugin.ll: it embeds its own
# private, statically linked copy of the AArch64 backend, built independently
# of whatever target(s) the host tool itself was built with, and implements
# PreCodeGenCallback to replace the host's backend entirely.
#
# Linking these archives statically pulls in a full private copy of the
# backend's transitive closure (Core, Support, MC, CodeGen, SelectionDAG,
# GlobalISel, ...), not just the AArch64-specific pieces. Left at their
# default visibility, these would collide with the host's own copies of the
# same globals (e.g. cl::opt, TargetRegistry, PassRegistry self-registration)
# once both are loaded into the same process -- see
# BackendPluginAArch64.exports, which localizes everything except the
# plugin's entry point so its private registries never merge with the host's.
unset(LLVM_LINK_COMPONENTS)
set(LLVM_LINK_COMPONENTS
  AArch64CodeGen
  AArch64Desc
  AArch64Info
  AArch64Utils
  )
set(LLVM_EXPORTED_SYMBOL_FILE ${CMAKE_CURRENT_SOURCE_DIR}/BackendPluginAArch64.exports)

add_llvm_library(BackendPluginAArch64 MODULE BUILDTREE_ONLY
  AArch64PreCodeGenCallback.cpp

  # This plugin needs its own, statically-linked copy of the AArch64
  # backend (see above), not the one inside libLLVM.so: keep it off
  # LLVM_LINK_COMPONENTS even when LLVM_LINK_LLVM_DYLIB is on.
  DISABLE_LLVM_LINK_LLVM_DYLIB

  DEPENDS
  intrinsics_gen
  vt_gen
  )

set_target_properties(BackendPluginAArch64 PROPERTIES FOLDER "Tests")
