# CMake >= 3.25.2 required for CUDA --std=c++20, >= 3.21 for HIP support.
cmake_minimum_required(VERSION 3.25.2...4.3.0 FATAL_ERROR)

# Specify the version of FLAMEGPU to use
# This should be released with a version tag once a releasee is made with HIP/ROCm support
# 4fa74199ad0623642b51c9e49fad3884c23f5419 is the commit where amdgpu was merged into master
# Override via the cache if this branch/commit/tag no longer exists.
set(FLAMEGPU_VERSION "4fa74199ad0623642b51c9e49fad3884c23f5419" CACHE STRING "FLAMEGPU/FLAMEGPU2 git branch or tag to use")
# If the above version is a hash instead, also set FLAMEGPU_VERSION_ALLOW_HASH to ON
set(FLAMEGPU_VERSION_ALLOW_HASH "ON")

# Create the project, only enabling c++ support as CUDA/HIP support is enabled based on FLAME GPU cache variable(s)
project(benchmark-flamegpu CXX)

# Find/Fetch benchmark-flamegpu dependencies before flamegpu2 so they are used instead (i.e. for nlohmann in spack builds) 
include(${CMAKE_CURRENT_LIST_DIR}/cmake/cli11.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/nlohmann_json.cmake)

# Conditionally include some extra CMake for spack builds, so that transitive dependencies of flamegpu2 are used from spack, without modifying upstream flamegpu2 (where full, cross platform support would require larger changes)
option(USE_SPACK_FLAMEGPU2_DEPS "Use Spack dependencies instead of FetchContent where supported" OFF)
if(USE_SPACK_FLAMEGPU2_DEPS)
    include(${CMAKE_CURRENT_LIST_DIR}/cmake/spack-deps.cmake)
endif()
# Include the cmake file which downloads and adds the flamegpu target (prior to cmake --install support being added upstream)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/flamegpu.cmake)

# Include common rules from the FLAMEGPU/FLAMEGPU2 repositories CMake
include(${FLAMEGPU_ROOT}/cmake/common.cmake)

# Find NVML/ROCmSMI depending on which language is supported (which is set in common.cmake)
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

# Dynamically generate a .cpp file which includes the git hash of this repository (if git is available)
# Use a custom target so this behaves when only git has been changed.
set(DYNAMIC_METADATA_IN "${CMAKE_CURRENT_SOURCE_DIR}/src/dynamic_metadata.cpp.in")
set(DYNAMIC_METADATA_OUT "${CMAKE_CURRENT_BINARY_DIR}/src/dynamic_metadata.cpp")
add_custom_target(${PROJECT_NAME}-metadata
    ALL
    COMMAND ${CMAKE_COMMAND}
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DINPUT_FILE=${DYNAMIC_METADATA_IN}
        -DOUTPUT_FILE=${DYNAMIC_METADATA_OUT}
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateDynamicMetadataCXX.cmake"
    BYPRODUCTS "${DYNAMIC_METADATA_OUT}"
    COMMENT "Generating ${DYNAMIC_METADATA_OUT}"
    VERBATIM
)

# List source files for the benchmark model
SET(ALL_SRC
    ${DYNAMIC_METADATA_OUT} # dynamicly generated
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/src/metadata.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cli.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cli.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D_fp32.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D_fp32.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D_fp64.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/circles_spatial3D_fp64.cu
)

# Define the binary target
flamegpu_add_executable("${PROJECT_NAME}" "${ALL_SRC}" "${FLAMEGPU_ROOT}" "${PROJECT_BINARY_DIR}" OFF)

# Ensure the dynamic metadata file generation is an explicit dependency
add_dependencies(${PROJECT_NAME} ${PROJECT_NAME}-metadata)

# ensure include directories are updated
target_include_directories("${PROJECT_NAME}" PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Forward the build configuration as a macro so it can be included in metadata output
target_compile_definitions("${PROJECT_NAME}" PRIVATE BUILD_TYPE="$<CONFIG>")

# link against additional dependencies
target_link_libraries("${PROJECT_NAME}" PRIVATE CLI11::CLI11)
target_link_libraries("${PROJECT_NAME}" PRIVATE nlohmann_json::nlohmann_json)

# link against gpu toolkit specific libraries
if(TARGET CUDA::nvml)
    target_link_libraries("${PROJECT_NAME}" PRIVATE CUDA::nvml)
endif()
if(TARGET rocm_smi64)
    target_link_libraries("${PROJECT_NAME}" PRIVATE rocm_smi64)  # might need to be amdsmi on some systems?
endif()

# Setup install rule for the benchmark-flamegpu target, so it can be installed by spack
# flamegpu2's common.cmake prevents cmake --install, so this must be worked around
# This will be fixed in a future flamegpu2 update. See https://github.com/FLAMEGPU/FLAMEGPU2/issues/260
set(CMAKE_SKIP_INSTALL_RULES OFF CACHE BOOL "" FORCE)
set(CMAKE_SKIP_INSTALL_RULES OFF)
include(GNUInstallDirs)
# Prevent top-level cmake_install.cmake from trying to include(cmake_install.cmake) from static/header-only dependencies in _deps/ such as flamegpu2 by excluding from all
get_property(dep_subdirs DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTY SUBDIRECTORIES)
foreach(subdir IN LISTS dep_subdirs)
    set_property(DIRECTORY "${subdir}" PROPERTY EXCLUDE_FROM_ALL TRUE)
endforeach()
# Define the install destination for benchmark-flamegpu
install(TARGETS "${PROJECT_NAME}"
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
