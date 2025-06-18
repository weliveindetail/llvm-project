add_llvm_library(ReferencePlugin SHARED INSTALL_WITH_TOOLCHAIN
  TestPlugin.cpp

  DEPENDS
  intrinsics_gen
)
