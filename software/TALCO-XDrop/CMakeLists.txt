cmake_minimum_required(VERSION 3.10)

project(TALCO-XDrop-build)

set(CMAKE_CUDA_COMPILER "/usr/local/cuda/bin/nvcc")
# find_package(CUDA 10.0 REQUIRED)

project(TALCO-XDrop-build LANGUAGES CXX)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O4 -std=c++17 -Wall -g")
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_52")

find_package(Boost COMPONENTS program_options REQUIRED)

find_package(ZLIB REQUIRED)
find_path(ZLIB_INCLUDE_DIR zlib.h)
include_directories(${ZLIB_INCLUDE_DIR})

add_executable (TALCO-XDrop
    src/TALCO-XDrop.cpp
    src/main.cpp)

target_link_libraries(TALCO-XDrop PRIVATE ${Boost_LIBRARIES} ${ZLIB_LIBRARIES})

