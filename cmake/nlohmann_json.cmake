# Fetch nlohmann/json via CMakeFetch content.
# This is also a dependency of flamegpu2 itself, so depending on inclusion order the flamegpu version may be found first.
include(FetchContent)

if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.28)
    list(APPEND DEPENDENCY_ARGS EXCLUDE_FROM_ALL)
endif()

FetchContent_Declare(
    nlohmann_json
    URL            "https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz"
    ${DEPENDENCY_ARGS}
    SYSTEM
    FIND_PACKAGE_ARGS 3.11.3 CONFIG
)
FetchContent_MakeAvailable(nlohmann_json)
