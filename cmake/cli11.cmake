# Fetch CLI11 via CMake.
# This can be replaced with a call to find_package when spack support is added.
include(FetchContent)

FetchContent_Declare(
    cli11
    GIT_REPOSITORY https://github.com/CLIUtils/CLI11
    GIT_TAG        v2.6.2
    GIT_SHALLOW    0
    GIT_PROGRESS   ON
    SYSTEM
)
FetchContent_MakeAvailable(cli11)

mark_as_advanced(CLI11_PRECOMPILED)
mark_as_advanced(CLI11_SANITIZERS)
mark_as_advanced(CLI11_SINGLE_FILE)
mark_as_advanced(CLI11_WARNINGS_AS_ERRORS)
