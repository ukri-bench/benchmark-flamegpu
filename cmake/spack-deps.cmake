# CMake used to conditionally use spack-provided transitive dependencies of FLAMEGPU2, as a temporary solution for offline spack builds prior to broader flamegpu2 spack packaging

if(USE_SPACK_FLAMEGPU2_DEPS)
    # Tinyxml2 in flamegpu2 is wrapped inside a directory on the include path to match other deps.
    # This was probably a bad decision as it means it does not play nicely with system-installed tinyxml2
    # Instead, find it here before flamegpu2 tries to, and create the shim.
    # The better solution is to not wrap the tinyxml2 header file in a directory in upstream flamegpu2

    # Ideally this should also enforce > 9.0.0, but relying on spack for that.
    find_package(tinyxml2 REQUIRED CONFIG)

    set(_tinyxml2_shim_dir "${CMAKE_CURRENT_BINARY_DIR}/_spack_shims")
    file(MAKE_DIRECTORY "${_tinyxml2_shim_dir}/tinyxml2")
    get_target_property(_tinyxml2_inc tinyxml2::tinyxml2 INTERFACE_INCLUDE_DIRECTORIES)
    list(GET _tinyxml2_inc 0 _tinyxml2_inc)
    file(WRITE "${_tinyxml2_shim_dir}/tinyxml2/tinyxml2.h" "#pragma once\n#include \"${_tinyxml2_inc}/tinyxml2.h\"\n")

    if(NOT TARGET tinyxml2)
        add_library(tinyxml2 INTERFACE)
        target_link_libraries(tinyxml2 INTERFACE tinyxml2::tinyxml2)
        target_include_directories(tinyxml2 SYSTEM INTERFACE "${_tinyxml2_shim_dir}")
        add_library(Tinyxml2::tinyxml2 ALIAS tinyxml2)
    endif()

    set(FETCHCONTENT_SOURCE_DIR_TINYXML2 "${_tinyxml2_shim_dir}" CACHE PATH "" FORCE)


endif()