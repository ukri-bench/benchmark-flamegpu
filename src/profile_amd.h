#pragma once

#include "flamegpu/flamegpu.h"

#if defined(FLAMEGPU_USE_HIP)
namespace {
    unsigned int profiled_step = std::numeric_limits<unsigned int>::max();
}
#include <hip/hip_runtime.h>
FLAMEGPU_STEP_FUNCTION(toggle_profiler) {
    if (FLAMEGPU->getStepCounter() + 1 == profiled_step) {
        roctxProfilerResume(0);
    } else if(FLAMEGPU->getStepCounter() == profiled_step) {
        roctxProfilerPause(0);
    }
}
inline void enable_profiler(flamegpu::ModelDescription &model, unsigned int step = 100) {
    // AMD profiler can't filter by ROCTX, so target step via profiler API
    profiled_step = step;
    model.addStepFunction(toggle_profiler);
    roctxProfilerPause(0);
}
#else
inline void enable_profiler(flamegpu::ModelDescription& /*model*/, unsigned int step = 100) {
    // nop (CUDA profiler can filter by NVTX)
}
#endif
