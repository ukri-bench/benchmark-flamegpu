#pragma once

#include <string>

#if defined(FLAMEGPU_USE_HIP)
#include <hip/hip_runtime.h>
#include <rocm_smi/rocm_smi.h>
#elif defined(FLAMEGPU_USE_CUDA)
#include <cuda_runtime.h>
#include <nvml.h>
#endif

namespace metadata {

/**
 * Get a string specifying the GPU toolkit name and version at compile time
 */
std::string gpu_toolkit_identifier() {
#if defined(FLAMEGPU_USE_HIP) && defined(HIP_VERSION_MAJOR) && defined(HIP_VERSION_MINOR) && defined(HIP_VERSION_PATCH)
    return "HIP " + std::to_string(HIP_VERSION_MAJOR) + "." + std::to_string(HIP_VERSION_MINOR) + "." + std::to_string(HIP_VERSION_PATCH);
#elif defined(FLAMEGPU_USE_CUDA) && defined(CUDA_VERSION)
    return "CUDA " + std::to_string(CUDA_VERSION / 1000) + "." + std::to_string((CUDA_VERSION % 1000) / 10);
#else
    return "UNKNOWN";
#endif
}

/**
 * Get a string specifying the GPU driver version via ROCm SMI / NVML
 * 
 * Todo: this doesn't handle HIP for Nvidia (which is untested / unsupported in general with FLAMEGPU2)
 */
std::string gpu_driver_identifier() {
#if defined(FLAMEGPU_USE_HIP)
    // get the driver version from rocm smi
    // Initialize ROCm SMI
    if (rsmi_init(0) != RSMI_STATUS_SUCCESS) {
        return "UNKNOWN (RMSI error)";
    }
    char version_str[256];
    rsmi_status_t status = rsmi_version_str_get(RSMI_SW_COMP_DRIVER, version_str, sizeof(version_str));
    // shutdown rsmi
    rsmi_shut_down();
    if (status == RSMI_STATUS_SUCCESS) {
        return std::string(version_str);
    } else {
        return "UNKNOWN AMD";
    }
#elif defined(FLAMEGPU_USE_CUDA)
    if (nvmlInit() != NVML_SUCCESS) {
        return "UNKNOWN (NVML error)";
    }
    char version_str[NVML_SYSTEM_DRIVER_VERSION_BUFFER_SIZE];
    nvmlReturn_t result = nvmlSystemGetDriverVersion(version_str, sizeof(version_str));
    nvmlShutdown();
    if (result == NVML_SUCCESS) {
        return std::string(version_str);
    } else {
        return "UNKNOWN NVIDIA";
    }
#else
    return "UNKNOWN";
#endif
}

}  // namespace metadata
