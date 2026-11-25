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

    # Must have one of the +cuda or +rocm variant enabled (no CPU builds). Ideally this should always be explicit, but extending CudaPackage & ROCmPackage seems to ignore sticky=True
    requires(
        "+cuda",
        "+rocm",
        policy="one_of",
        msg="One of either +cuda or +rocm must be enabled",
    )
    # enforce cuda_arch must be set, for consisteny between +cuda and +rocm (although compiler defaults would produce valid binaries)
    conflicts("cuda_arch=none", when="+cuda", msg="CUDA architecture is required")

    # Direct dependencies of benchmark-flamegpu
    depends_on("c", type="build")
    depends_on("cxx", type="build")
    depends_on("cmake@3.25.2:4.3", type="build")
    depends_on("git@1.6.6:", type="build")  # techincally optional

    depends_on("nlohmann-json@3.11.3:")
    depends_on("cli11@2.5:")
    with when("+rocm"):
        depends_on("rocm-smi-lib")
    # Note: NVML is not a separate spack package

    # FLAMEGPU2 is not (yet) an independent spack package (it cannot be --installed), instead specify some transitive dependencies for now (excluding un-used/not relevant dependencies)
    # depends_on("flamegpu2", type="build")  # variants would need to match

    # Instead, we can define it as a resource for now so it is fetched by spack not CMake and force CMake to use this version. This does duplicate where versions are stored.
    resource(
        name="flamegpu2",
        git="https://github.com/FLAMEGPU/FLAMEGPU2.git",
        tag="4fa74199ad0623642b51c9e49fad3884c23f5419",  # amdgpu support commit in master
        destination="spack-resources",
        placement="flamegpu2",
    )
    # CUDA >= 12.4 supported by FLAMEGPU 2.0.0-rc.6
    depends_on("cuda@12.4:", when="+cuda")
    # HIP/ROCM >= 7.0 supported by FLAMEGPU 2.0.0-rc.6
    depends_on("hip@7.0:", when="+rocm")
    # Generic transivitve dependencies from flamegpu2
    # depends_on("nlohmann-json@3.11.3:") # duplicate, commented out until separated.
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
        depends_on("rocprofiler-sdk", when="+profiling")

    # Define where the root CMakeLists.txt is within the benchmark-flamegpu repository
    root_cmakelists_dir = "."

    def setup_build_environment(self, env: EnvironmentModifications) -> None:
        # Various ROCm/HIP CMakeLists set -x hip or --offload-arch for cxx objects, so must alwasy use a hip-aware host compiler, i.e. not gcc
        if self.spec.satisfies("+rocm"):
            env.set("CC", self.spec["hip"].hipcc)
            env.set("CXX", self.spec["hip"].hipcc)

    def cmake_args(self):
        args = [
            # Always forward the value for seatbelts, defaults to ON in CMake
            self.define("FLAMEGPU_SEATBELTS", self.spec.variants["seatbelts"].value),
            # Alwasy forward if profiling should be enabled value
            self.define(
                "FLAMEGPU_ENABLE_PROFILING", self.spec.variants["profiling"].value
            ),
            # Usage telemetry defautls to ON, so always specify a value (and suppress the notice)
            self.define(
                "FLAMEGPU_SHARE_USAGE_STATISTICS", self.spec.variants["telemetry"].value
            ),
            self.define("FLAMEGPU_TELEMETRY_SUPPRESS_NOTICE", "ON"),
            # configure this cmake to explcitly use spack-provided transitive dependencies
            self.define("USE_SPACK_FLAMEGPU2_DEPS", "ON"),
            # Make fetch content not use the internet, to ensure offline builds work
            self.define("FETCHCONTENT_FULLY_DISCONNECTED", True),
        ]

        # Define ROCm only cmake arguments
        if self.spec.satisfies("+rocm"):
            # Explicitly set amdclang++ as the hip compiler
            args.append(
                self.define(
                    "CMAKE_HIP_COMPILER",
                    os.path.join(self.spec["llvm-amdgpu"].prefix.bin, "amdclang++"),
                )
            )
            args.append(self.define("FLAMEGPU_BACKEND", "HIP"))
            args.append(
                self.define(
                    "CMAKE_HIP_ARCHITECTURES", self.spec.variants["amdgpu_target"].value
                )
            )

        # Define CUDA only cmake arguments
        if self.spec.satisfies("+cuda"):
            args.append(self.define("FLAMEGPU_BACKEND", "CUDA"))
            args.append(
                self.define(
                    "CMAKE_CUDA_ARCHITECTURES", self.spec.variants["cuda_arch"].value
                )
            )

        # Ensure the spack-defined resource for flamegpu2 is used (prior to it becoming a spack package itself)
        flamegpu_root = os.path.join(
            self.stage.source_path, "spack-resources", "flamegpu2"
        )
        if os.path.exists(flamegpu_root):
            args.append(self.define("FLAMEGPU_ROOT", flamegpu_root))
        # Use the spack-resource jitify2 (if appropraite)
        if self.spec.satisfies("+cuda"):
            jitify_root = os.path.join(
                self.stage.source_path, "spack-resources", "jitify"
            )
            if os.path.exists(jitify_root):
                args.append(self.define("FETCHCONTENT_SOURCE_DIR_JITIFY", jitify_root))

        return args
