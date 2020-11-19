# Build for all components of the ORC runtime support library.

# ORC runtime library implementation files.
set(ORC_SOURCES
  orc_rt_cxa.cpp
  orc_rt_log_error_to_stderr.cpp
  orc_rt_macho_dlfcn.cpp
  orc_rt_macho_dlfcn_local.cpp
  orc_rt_macho_dlfcn_remote.cpp
  orc_rt_macho_run_program.cpp
  )

# Implementation files for all ORC architectures.
set(x86_64_SOURCES
  orc_x86_64.S
  )

set(ORC_IMPL_HEADERS
  orc_rt_common.h
  orc_rt_cxa.h
  orc_rt_remote_dispatch.h
  orc_rt_macho_dlfcn.h
  )

# Create list of all source files for
# consumption by tests.
set(ORC_ALL_SOURCE_FILES
  ${ORC_SOURCES}
  ${x86_64_SOURCES}
  ${ORC_IMPL_HEADERS}
  )

list(REMOVE_DUPLICATES ORC_ALL_SOURCE_FILES)

# Make list that uses absolute paths
set(ORC_ALL_SOURCE_FILES_ABS_PATHS "")
foreach (src_file ${ORC_ALL_SOURCE_FILES})
  list(APPEND
    ORC_ALL_SOURCE_FILES_ABS_PATHS
    "${CMAKE_CURRENT_SOURCE_DIR}/${src_file}")
endforeach()


# Now put it all together...
include_directories(..)
include_directories(../../include)

set(ORC_CFLAGS ${COMPILER_RT_COMMON_CFLAGS})

add_compiler_rt_component(orc)

# ORC uses C++ standard library headers.
if (TARGET cxx-headers OR HAVE_LIBCXX)
  set(ORC_DEPS cxx-headers)
endif()

if (APPLE)
  add_compiler_rt_object_libraries(RTOrc
    OS ${ORC_SUPPORTED_OS}
    ARCHS ${ORC_SUPPORTED_ARCH}
    SOURCES ${ORC_SOURCES} ${x86_64_SOURCES}
    ADDITIONAL_HEADERS ${ORC_IMPL_HEADERS}
    CFLAGS ${ORC_CFLAGS})

  # We only support running on osx for now.
  add_compiler_rt_runtime(clang_rt.orc
    STATIC
    OS ${ORC_SUPPORTED_OS}
    ARCHS ${ORC_SUPPORTED_ARCH}
    OBJECT_LIBS RTOrc
    CFLAGS ${ORC_CFLAGS}
    LINK_FLAGS ${SANITIZER_COMMON_LINK_FLAGS} ${WEAK_SYMBOL_LINK_FLAGS}
    LINK_LIBS ${ORC_LINK_LIBS}
    PARENT_TARGET orc)
else() # not Apple
  foreach(arch ${ORC_SUPPORTED_ARCH})
    if(NOT CAN_TARGET_${arch})
      continue()
    endif()
    add_compiler_rt_object_libraries(RTOrc
      ARCHS ${arch}
      SOURCES ${ORC_SOURCES} ${${arch}_SOURCES}
      ADDITIONAL_HEADERS ${ORC_IMPL_HEADERS}
      CFLAGS $ORC_CFLAGS}
      DEPS ${ORC_DEPS})

    # Common ORC archive for instrumented binaries.
    add_compiler_rt_runtime(clang_rt.orc
     STATIC
     ARCHS ${arch}
     CFLAGS ${ORC_CFLAGS}
     OBJECT_LIBS ${ORC_COMMON_RUNTIME_OBJECT_LIBS} RTOrc
     PARENT_TARGET orc)
  endforeach()
endif() # not Apple
