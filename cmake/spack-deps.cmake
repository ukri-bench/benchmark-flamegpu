# Optional workaround so that relevant FLAMEGPU2 dependencies can be found and setup prior to being fetched by flamegpu2 CMake
# I.e. For spack installs prior to flamegpu2 having a separate spack package
if(USE_SPACK_FLAMEGPU2_DEPS)
    # Tinyxml2 in flamegpu2 is wrapped inside a directory on the include path to match other dependencies (and always fetched by default)
    # This does not match the layout of upstream Tinyxml2 in CMake, leading to issues. 
    # Instead, find it here before flamegpu2 tries to, and create the shim.
    # This will be addressed in flamegpu2 for a future release. see https://github.com/FLAMEGPU/FLAMEGPU2/issues/1441

    # Ideally this should also enforce > 9.0.0, but tinyxml2 find package does major version matching. Assume the found version is compatible.
    find_package(tinyxml2 REQUIRED CONFIG)

    set(tinyxml2_shim_dir "${CMAKE_CURRENT_BINARY_DIR}/_dependency_shims")
    file(MAKE_DIRECTORY "${tinyxml2_shim_dir}/tinyxml2")
    get_target_property(tinyxml2_inc tinyxml2::tinyxml2 INTERFACE_INCLUDE_DIRECTORIES)
    list(GET tinyxml2_inc 0 tinyxml2_inc)
    file(WRITE "${tinyxml2_shim_dir}/tinyxml2/tinyxml2.h" "#pragma once\n#include \"${tinyxml2_inc}/tinyxml2.h\"\n")

    if(NOT TARGET tinyxml2)
        add_library(tinyxml2 INTERFACE)
        target_link_libraries(tinyxml2 INTERFACE tinyxml2::tinyxml2)
        target_include_directories(tinyxml2 SYSTEM INTERFACE "${tinyxml2_shim_dir}")
        add_library(Tinyxml2::tinyxml2 ALIAS tinyxml2)
    endif()

    set(FETCHCONTENT_SOURCE_DIR_TINYXML2 "${tinyxml2_shim_dir}" CACHE PATH "" FORCE)
    
    unset(tinyxml2_inc)
    unset(tinyxml2_shim_dir)
endif()