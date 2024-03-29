# See below option statements and the README for build information

cmake_minimum_required(VERSION 3.16)
project(wfa2lib)

set(CMAKE_CXX_STANDARD 17)

include(FeatureSummary)
include(GNUInstallDirs)

find_package(PkgConfig REQUIRED)

feature_summary(
  FATAL_ON_MISSING_REQUIRED_PACKAGES
  WHAT REQUIRED_PACKAGES_NOT_FOUND)

# ---- Options

option(OPENMP "Enable OpenMP" OFF) # enables WFA_PARALLEL
option(PROFILING "Enable profiling" OFF)
option(ASAN "Use address sanitiser" ON)
option(EXTRA_FLAGS "Add optimization flags for C/C++ compiler" OFF)

# include(CheckIPOSupported) # adds lto
# check_ipo_supported(RESULT ipo_supported OUTPUT output)

# ---- Dependencies

if(OPENMP)
  include(FindOpenMP)
  set(OPTIMIZE_FLAGS "-DWFA_PARALLEL")
endif(OPENMP)

if(EXTRA_FLAGS)
  set(OPTIMIZE_FLAGS "${OPTIMIZE_FLAGS} ${EXTRA_FLAGS}")
endif(EXTRA_FLAGS)

find_package(Threads)
set_package_properties(Threads PROPERTIES TYPE REQUIRED)

# ---- Build switches
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
# set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ${ipo_supported})

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING
          "Choose the type of build, options are: Release|Debug|RelWithDebInfo (for distros)." FORCE)
endif()

if (${CMAKE_BUILD_TYPE} MATCHES Release)
  set(OPTIMIZE_FLAGS "${OPTIMIZE_FLAGS} -march=native -D_FILE_OFFSET_BITS=64")
endif()

if ((${CMAKE_BUILD_TYPE} MATCHES Release) OR (${CMAKE_BUILD_TYPE} MATCHES RelWithDebInfo))
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS} ${OPTIMIZE_FLAGS}")
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS} ${OPTIMIZE_FLAGS}")
endif ()

if (${CMAKE_BUILD_TYPE} MATCHES "Debug")
  set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OPTIMIZE_FLAGS}")
  set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OPTIMIZE_FLAGS}")
endif ()

#if (ASAN)
  set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address  -fno-omit-frame-pointer -fno-common")
  set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address  -fno-omit-frame-pointer -fno-common")
#endif(ASAN)

if(PROFILING)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
endif(PROFILING)

if(GPROF)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg")
endif(GPROF)

# ---- Include files

include_directories(wavefront)
include_directories(utils)
include_directories(.)

file(GLOB INCLUDES
  wavefront/*.h*
  utils/*.h*
  )

file(GLOB OTHER_SRCS "utils/*.c" "utils/*.h" "system/*.c" "system/*.h" "alignment/*.c" "alignment/*.h")

set(wfa2lib_SOURCE
  wavefront/wavefront_align.c
  wavefront/wavefront_aligner.c
  wavefront/wavefront_attributes.c
  wavefront/wavefront_backtrace_buffer.c
  wavefront/wavefront_backtrace.c
  wavefront/wavefront_backtrace_offload.c
  wavefront/wavefront_bialign.c
  wavefront/wavefront_bialigner.c
  wavefront/wavefront.c
  wavefront/wavefront_components.c
  wavefront/wavefront_compute_affine2p.c
  wavefront/wavefront_compute_affine.c
  wavefront/wavefront_compute.c
  wavefront/wavefront_compute_edit.c
  wavefront/wavefront_compute_linear.c
  wavefront/wavefront_debug.c
  wavefront/wavefront_display.c
  wavefront/wavefront_extend.c
  wavefront/wavefront_heuristic.c
  wavefront/wavefront_pcigar.c
  wavefront/wavefront_penalties.c
  wavefront/wavefront_plot.c
  wavefront/wavefront_slab.c
  wavefront/wavefront_unialign.c
)


add_library(wfa
    ${wfa2lib_SOURCE}
    )

add_executable(TALCO-WFAA
    ${wfa2lib_SOURCE}
    ${OTHER_SRCS}
    tiling_test/err_stats.cpp
    tiling_test/err_stats.hpp
    tiling_test/nanosim_input.cpp
    tiling_test/main.cpp
)
add_executable(wfa_debug_test
    ${wfa2lib_SOURCE}
    ${OTHER_SRCS}
    tiling_test/err_stats.cpp
    tiling_test/err_stats.hpp
    tiling_test/nanosim_input.cpp
    tiling_test/debug_main.cpp
)

    # ---- Get version

file (STRINGS "VERSION" BUILD_NUMBER)
add_definitions(-DWFA2LIB_VERSION="${BUILD_NUMBER}")
add_definitions(-DVERSION="${BUILD_NUMBER}")

set(wfa2lib_LIBS
)

# add_dependencies(wfa2lib ${wfa2lib_DEPS})

# ---- Build all

# ---- Test

enable_testing()


function(add_wfa_test)
  add_test(
    NAME wfa2lib
    COMMAND ./tests/wfa.utest.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endfunction()

add_wfa_test()

# ---- Install

#install(TARGETS wfa ARCHIVE DESTINATION lib)

#install(FILES ${INCLUDES} DESTINATION include/wfa2lib)

# install(DIRECTORY ${CMAKE_SOURCE_DIR}/man/ DESTINATION ${CMAKE_INSTALL_PREFIX}/man/man1)
