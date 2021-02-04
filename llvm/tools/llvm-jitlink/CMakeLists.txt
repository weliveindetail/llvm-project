if ( LLVM_INCLUDE_UTILS )
  add_subdirectory(llvm-jitlink-executor)
endif()

set(LLVM_LINK_COMPONENTS
  AllTargetsDescs
  AllTargetsDisassemblers
  AllTargetsInfos
  BinaryFormat
  ExecutionEngine
  JITLink
  MC
  Object
  OrcJIT
  OrcShared
  OrcTargetProcess
  RuntimeDyld
  Support
  )

add_llvm_tool(llvm-jitlink
  llvm-jitlink.cpp
  llvm-jitlink-elf.cpp
  llvm-jitlink-macho.cpp
  )

# If compiler-rt is enabled in this build and the ORC runtime target
# for our platform exists, we can default enable the UseOrcRuntime option
# in llvm-jitlink.
if (APPLE AND CMAKE_SYSTEM_NAME MATCHES Darwin)
  # We cannot use get_target_property() here, because compiler-rt is configured
  # after LLVM (so the respective target doesn't exist yet). Instead we use a
  # generator expression, which evaluates after all targets were configured.
  # For that to work we add a manual generation-step for the config file below.
  set(USE_ORC_RUNTIME_DEFAULT $<TARGET_EXISTS:clang_rt.orc_osx>)
else()
  set(USE_ORC_RUNTIME_DEFAULT 0)
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/llvm-jitlink-config.h.in
               ${CMAKE_CURRENT_BINARY_DIR}/llvm-jitlink-config.h.conf @ONLY)
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/llvm-jitlink-config.h
              INPUT ${CMAKE_CURRENT_BINARY_DIR}/llvm-jitlink-config.h.conf)

export_executable_symbols(llvm-jitlink)
