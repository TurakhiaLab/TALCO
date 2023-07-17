cmake_minimum_required(VERSION 3.10)

project(xact-build)

set(CMAKE_CUDA_COMPILER "/usr/local/cuda/bin/nvcc")
# find_package(CUDA 10.0 REQUIRED)

project(xact-build LANGUAGES CXX)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O4 -std=c++17 -Wall -g")
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_52")

find_package(Boost COMPONENTS program_options REQUIRED)

find_package(ZLIB REQUIRED)
find_path(ZLIB_INCLUDE_DIR zlib.h)
include_directories(${ZLIB_INCLUDE_DIR})

add_executable (xact
    src/xact.cpp
    src/main.cpp)

# add_executable (xact-cpu-s2
#    src/xact-cpu-s2.cpp
#    src/main.cpp)

# add_executable (xact
#    src/xact.cu
#    src/main.cpp)

#target_link_libraries(xact-cpu-s2 PRIVATE ${Boost_LIBRARIES} ${ZLIB_LIBRARIES})
#target_link_libraries(xact-cpu PRIVATE ${Boost_LIBRARIES} ${ZLIB_LIBRARIES})
target_link_libraries(xact PRIVATE ${Boost_LIBRARIES} ${ZLIB_LIBRARIES})

