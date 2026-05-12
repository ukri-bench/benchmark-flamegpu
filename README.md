# FLAMEGPU benchmark

This repository provides a set of performance benchmarks of [FLAME GPU](https://github.com/FLAMEGPU/FLAMEGPU2) - a GPU accelerated Agent Based Simulation library.

This repository is part of the part of the UKRI Living Benchmarks project.

## Status

Alpha

## Maintainers

- [Peter Heywood](https://github.com/ptheywood)
- [Paul Richmond](https://github.com/mondus)
<!-- - Todo: [Maintainer from the living benchmarks project](https://github.com/) -->

## Overview

### Software

- [FLAME GPU 2](https://github.com/FLAMEGPU/FLAMEGPU2)

### Architectures

- GPU: NVIDIA, AMD

### Languages and programming models

- Programming languages: C++, CUDA, ROCm/HIP
- Accelerator offload models: CUDA, HIP

<!-- ### Seven 'dwarfs'

- [ ] Dense linear algebra
- [ ] Sparse linear algebra
- [ ] Spectral methods
- [ ] N-body methods
- [ ] Structured grids
- [ ] Unstructured grids
- [ ] Monte Carlo -->

## Building the benchmark

The benchmark can currently only be built manually via CMake. 

<!-- The benchmark can be built using Spack or manually. If you are using the 
ReFrame method to run the benchmark described below, it will automatically
perform the build step for you.

Once it has been built the benchmark executable is called `name-of-exe.x` -->

<!-- ### Spack build

A Spack package is provided in `spack/`:

```bash
spack repo add ./spack
spack info <package name>
```
- ADD: Describe Spack spec and variants available

Note: to use Spack, you must have Spack installed on the system you are using and
a valid Spack system configuration. Example Spack configurations are available
in a separate repository: [https://github.com/ukri-bench/system-configs] -->

### Manual build

This benchmark is configured as a CMake project which will fetch the required FLAME GPU source code during configuration, and requires:

- CMake >= `3.25.2`

with either:

- CUDA >= `12.4` with a compatible GCC >= `11` (for c++20 support)
  - Compatible clang installations with c++20 support may work, but are currently untested / not supported by FLAME GPU 2 
- HIP/ROCm >= `7.0` with the included `hipcc`
  - The ROCm CMake modules must be discoverable by `find_package`

Clone this repository

```bash
git clone https://github.com/ukri-bench/benchmark-flamegpu.git
```

Configure using `cmake`, with the appropriate compilers and CMake Configuration arguments for the platform (updating `CMAKE_CUDA_ARCHITECTURES` or `CMAKE_HIP_ARCHITECTURES` with the appropriate value for the system):

For Nvidia GPUs (with Ampere GPUs as the example `CMAKE_CUDA_ARCHITECTURES`)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=80 -DFLAMEGPU_GPU=CUDA -DFLAMEGPU_SEATBELTS=OFF
```

For AMD GPUs (with Mi350x as the example `CMAKE_HIP_ARCHITECTURES`):

```bash
CC=hipcc CXX=hipcc cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_HIP_ARCHITECTURES=gfx942 -DFLAMEGPU_GPU=HIP -DFLAMEGPU_SEATBELTS=OFF
```

Build the benchmark target(s) using CMake 

```bash
cmake --build build --target all -j `nproc`
```

## Running the benchmark

The benchmark must be run manually at this time.

<!-- The benchmark can be run using ReFrame or manually. 

If you use ReFrame, then ReFrame will build the software, run the benchmark,
test for correctness, extract the performance/figure of merit (FoM) for you and
report them.

### Running using ReFrame

The ReFrame test configuration is available in the `reframe/` subdirectory.

ADD: Instructions on running ReFrame for this benchmark.

Note: to use ReFrame, you must have ReFrame installed on the system you are using and
a valid ReFrame system configuration. Example ReFrame configurations are available
in a separate repository: [https://github.com/ukri-bench/system-configs] -->

### Running manually

Assuming `build` was used as the CMake build directory:

<!-- Todo: example job submission scripts in separate files in the repo) -->

```bash
cd build
./bin/Release/benchmark-flamegpu
```

> [!CAUTION]
> - Todo: Example of how to test correctness
> - Todo: Example of how to extract performance/FoM

## Example performance data

This section contains example performance data from selected HPC systems.

> [!CAUTION]
> - Todo: Example performance data

> [!CAUTION]
> Add caveats related to the performance data (timing captured internally excludes X/Y/Z)

## License

This benchmark description and associated files are released under the GNU AGPLv3.
