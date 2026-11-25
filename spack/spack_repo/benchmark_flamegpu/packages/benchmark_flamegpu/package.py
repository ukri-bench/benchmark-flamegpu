import os

from spack_repo.builtin.build_systems.cmake import CMakePackage
from spack_repo.builtin.build_systems.cuda import CudaPackage
from spack_repo.builtin.build_systems.rocm import ROCmPackage

from spack.package import *


class BenchmarkFlamegpu(CMakePackage, CudaPackage, ROCmPackage):
    "A benchmark using FLAMEGPU2 as part of the [UKRI living benchmarks project](https://ukri-bench.github.io)"

    homepage = "https://github.com/ukri-bench/ukri-bench"
    git = "https://github.com/ukri-bench/benchmark-flamegpu.git"

    license("AGPL-3.0-only")
    maintainers("ptheywood", "mondus", "robadob")

    version("main", tag="main", no_cache=True)    

    variant(
        "seatbelts",
        default=False,
        description="Enable FLAMEGPU_SEATBELTS, adding additional runtime checks and improved error messages at the cost or raw perforamnce. This is typically intended for use during model development.",
    )
    variant(
        "profiling",
        default=False,
        description="Enable nvtx/roctx profiling for profiling",
    )
    variant(
        "telemetry",
        default=False,
        description="Share usage statistics ([telemetry](https://docs.flamegpu.com/guide/telemetry)) to support evidencing usage/impact of the software",
    )


    depends_on("c", type="build")
    depends_on("cxx", type="build")
    
    # Cmake >= 3.25.2 required
    depends_on("cmake@3.25.2:4.3", type="build")


    # Must have one of the CUDA or ROCm variant enabled (GPU only). Ideally this should always be explicit, but extending CudaPackage & ROCmPackage seems to ignore sticky=True
    variant("cuda", default=False, sticky=True, description="Build with CUDA")
    variant("rocm", default=False, sticky=True, description="Build with ROCm/HIP")
    requires("+cuda", "+rocm", policy="one_of", msg="Must enable either +cuda or +rocm")
    
    # enforce cuda_arch must be set, for consisteny with ROCm spack. (this is not strictly required)
    conflicts("cuda_arch=none", when="+cuda", msg="CUDA architecture is required")

    # CUDA >= 12.4 supported by FLAMEGPU 2 
    depends_on("cuda@12.4:", when="+cuda")
    
    # HIP/ROCM >= 7.0 supported    
    depends_on("hip@7.0:", when="+rocm")

    # CUDA only dependencies
    with when("+cuda"):
        # nvml not a separate spack pacakge
        pass

    # ROCM only dependencies
    with when("+rocm"):
        depends_on("rocm-smi-lib") # for metadata collection

    # benchmark-flamegpu dependencies regardless of build type
    depends_on("nlohmann-json@3.11.3:")
    depends_on("cli11@2.5:") # spack 1.2.2 only includes 2.5.0. We fetch 2.6.2 in cmake
    depends_on("git@1.6.6:", type="build") # techincally optional, but adds build metadata
    

    # FLAMEGPU2 is not (yet) an independent spack package (it cannot be --installed), instead specify some transitive dependencies for now (excluding un-used/not relevant dependencies)
    # depends_on("flamegpu2", type="build")  # variants would need to match

    # Instead, we can define it as a resource for now so it is fetched by spack not CMake and force CMake to use this version. This does duplicate where versions are stored.
    resource(
        name="flamegpu2",
        git="https://github.com/FLAMEGPU/FLAMEGPU2.git",
        tag="4fa74199ad0623642b51c9e49fad3884c23f5419", # amdgpu support commit in master
        destination="spack-resources",
        placement="flamegpu2",
    )

    # Generic transivitve dependencies from flamegpu2
    # depends_on("nlohmann-json@3.11.3:") # duplicated
    depends_on("tinyxml2@9.0.0:")
    depends_on("git", type="build")
    # CUDA only transitive dependencies from flamegpu2
    with when("+cuda"):
        # depends_on("cccl") # spack concretizier is failing with cccl, ignoring for now (the version that ships with CUDA should be fine)
        depends_on("nvtx@3:", when="+profiling")
        # jitify is not correctly versioned, requires custom patching and is not a spack package.
        # Instead, donwnload the relevant upstream commit into a spack resource
        resource(
            name="jitify",
            git="https://github.com/NVIDIA/jitify.git",
            commit="44e978b21fc8bdb6b2d7d8d179523c8350db72e5",
            destination="spack-resources",
            placement="jitify",
        )
    # ROCM only transivitve dependencies from flamegpu2
    with when("+rocm"):
        depends_on("rocm-core")
        depends_on("rocthrust")
        depends_on("hipcub")
        depends_on("hiprand")
        depends_on("rocprofiler-sdk", when="+profiling") # maybe rocprofiler-dev ?


    # Define where the root CMakeLists.txt is within the benchmark-flamegpu repository
    root_cmakelists_dir = "."

    def cmake_args(self):
        args = []

        # Enable ROCm and forward architectures
        if self.spec.satisfies("+rocm"):
            args.append(self.define("FLAMEGPU_BACKEND", "HIP"))
            args.append(
                self.define("CMAKE_HIP_ARCHITECTURES", self.spec.variants["amdgpu_target"].value)
            )

        # Enable CUDA and forward architectures
        if self.spec.satisfies("+cuda"):
            args.append(self.define("FLAMEGPU_BACKEND", "CUDA"))
            args.append(self.define("CMAKE_CUDA_ARCHITECTURES", self.spec.variants["cuda_arch"].value))

        # Get CMake to use the spack resource FLAMEGPU2 rather than using fetch content via FLAMEGPU_ROOT
        flamegpu_root = os.path.join(self.stage.source_path, "spack-resources", "flamegpu2")
        if os.path.exists(flamegpu_root):
            args.append(self.define("FLAMEGPU_ROOT", flamegpu_root))

        # Use the spack-resource jitify2, if appropraite
        if self.spec.satisfies("+cuda"):
            jitify_root = os.path.join(self.stage.source_path, "spack-resources", "jitify")
            if os.path.exists(jitify_root):
                args.append(self.define("FETCHCONTENT_SOURCE_DIR_JITIFY", jitify_root))

        # Always forward the value for seatbelts, defaults to ON in CMake
        args.append(self.define("FLAMEGPU_SEATBELTS", self.spec.variants["seatbelts"].value))

        # Alwasy forward if profiling should be enabled value
        args.append(self.define("FLAMEGPU_ENABLE_PROFILING", self.spec.variants["profiling"].value))

        # Usage telemetry defautls to ON, so always specify a value (and suppress the notice)
        args.append(self.define("FLAMEGPU_SHARE_USAGE_STATISTICS", self.spec.variants["telemetry"].value))
        args.append(self.define("FLAMEGPU_TELEMETRY_SUPPRESS_NOTICE", "ON"))

        # configure this cmake to explcitly use spack-provided transitive dependencies
        args.append(self.define("USE_SPACK_FLAMEGPU2_DEPS", "ON"))

        # Encourage CMake to find packages before fetching them, this might work...
        # args.append(self.define("FETCHCONTENT_TRY_FIND_PACKAGE_MODE", "ALWAYS"))

        # Make fetch content not use the internet, to ensure offline builds work
        args.append(self.define("FETCHCONTENT_FULLY_DISCONNECTED", True))

        return args