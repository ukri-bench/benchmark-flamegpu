# CMake >= 3.25.2 required for CUDA --std=c++20, >= 3.21 for HIP support.
cmake_minimum_required(VERSION 3.25.2...4.3.0 FATAL_ERROR)

# Specify the version of FLAMEGPU to use
# This will need changing once the amdgpu branch is merged, and a tagged version is released. This current value is ephemeral.
# Override via the cache if this branch no longer exists.
set(FLAMEGPU_VERSION "amdgpu" CACHE STRING "FLAMEGPU/FLAMEGPU2 git branch or tag to use")
# If the above version is a hash instead, also set FLAMEGPU_VERSION_ALLOW_HASH to ON
set(FLAMEGPU_VERSION_ALLOW_HASH "ON")

# Include the cmake file which downloads and adds the flamegpu target (prior to cmake --install support being added)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/flamegpu.cmake)

# Create the project, only enabling c++ support for now as CUDA/HIP enablement depends on the FLAMEGPU_GPU cache variable
project(benchmark-flamegpu CXX)

# Include common rules from the FLAMEGPU/FLAMEGPU2 repositories CMake
include(${FLAMEGPU_ROOT}/cmake/common.cmake)

# Find/Fetch any additional dependencies
include(${CMAKE_CURRENT_LIST_DIR}/cmake/cli11.cmake)
# nlohmann_json is a FLAME GPU dependency, so should already be a target.
if (NOT TARGET nlohmann_json)
    find_package(nlohmann_json REQUIRED) 
endif()


# Find NVML/ROCmSMI depending on which language is supported
if(CMAKE_CUDA_COMPILER_LOADED)
    find_package(CUDAToolkit REQUIRED)
    if (NOT TARGET CUDA::nvml)
        message(FATAL_ERROR "CUDA::nvml is required but not found as part of CUDAToolkit")
    endif()
endif()
if(CMAKE_HIP_COMPILER_LOADED)
    find_package(rocm_smi REQUIRED)
endif()

# Define output location of binary files (matching visual studio structure for consistency)
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE}/)

# List source files for the benchmark model
SET(ALL_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/src/metadata.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D.cu
)

# Define the binary target
flamegpu_add_executable("${PROJECT_NAME}" "${ALL_SRC}" "${FLAMEGPU_ROOT}" "${PROJECT_BINARY_DIR}" OFF)

# ensure include directories are updated
target_include_directories("${PROJECT_NAME}" PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

# link against additional dependencies
target_link_libraries("${PROJECT_NAME}" PRIVATE CLI11::CLI11)
target_link_libraries("${PROJECT_NAME}" PRIVATE nlohmann_json)

# link against gpu toolkit specific libraries
if(CMAKE_CUDA_COMPILER_LOADED)
    target_link_libraries("${PROJECT_NAME}" PRIVATE CUDA::nvml)
endif()
if(CMAKE_HIP_COMPILER_LOADED)
    target_link_libraries("${PROJECT_NAME}" PRIVATE rocm_smi::rocm_smi)  # might need to be amdsmi on some systems?
endif()