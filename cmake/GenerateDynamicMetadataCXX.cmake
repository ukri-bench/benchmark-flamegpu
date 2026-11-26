# CMake to be executed as a custom target which generates the dynamic metadata cpp file in the binary directory
set(BENCHMARK_FLAMEGPU_GIT_DESCRIBE "UNKNOWN")

find_package(Git QUIET)
if(Git_FOUND)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --always --dirty
        WORKING_DIRECTORY "${SOURCE_DIR}"
        RESULT_VARIABLE GIT_DESCRIBE_RESULT
        OUTPUT_VARIABLE GIT_DESCRIBE_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(GIT_DESCRIBE_RESULT EQUAL 0)
        set(BENCHMARK_FLAMEGPU_GIT_DESCRIBE "${GIT_DESCRIBE_OUTPUT}")
    endif()
endif()

# configure_file only updates the timestamp of the output file if its contents changed
configure_file("${INPUT_FILE}" "${OUTPUT_FILE}" @ONLY)