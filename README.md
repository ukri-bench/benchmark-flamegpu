# Template benchmark

The repository demonstrates/describes the structure of a repository for a 
benchmark released as part of the UKRI Living Benchmarks project.

## Status

Alpha

## Maintainers

- Maintainer 1 (Link to github profile)
- Maintainer 2 (Link to github profile)
- ...

## Overview

### Software

- ADD: Link to repo/website for main software/framework/library for the benchmark
- (Optional) ADD: Link to source code for benchmark case (required when software is a framework
  or library and so does not have an executable that can be used for benchmarking)

### Architectures

- CPU: *e.g. x86, Arm*
- GPU: *e.g. NVIDIA, AMD, Intel*
- Other: *e.g. Cerebras, ...*

### Languages and programming models

- Programming languages: *e.g. Fortran, C++, Python*
- Parallel models: *e.g. MPI, OpenMP*
- Accelerator offload models: *e.g. CUDA, HIP, OpenACC, Kokkos*

### Seven 'dwarfs'

- [ ] Dense linear algebra
- [ ] Sparse linear algebra
- [ ] Spectral methods
- [ ] N-body methods
- [ ] Structured grids
- [ ] Unstructured grids
- [ ] Monte Carlo

## Building the benchmark

The benchmark can be built using Spack or manually. If you are using the 
ReFrame method to run the benchmark described below, it will automatically
perform the build step for you.

Once it has been built the benchmark executable is called `name-of-exe.x`

### Spack build

A Spack package is provided in `spack/`:

```bash
spack repo add ./spack
spack info <package name>
```
- ADD: Describe Spack spec and variants available

Note: to use Spack, you must have Spack installed on the system you are using and
a valid Spack system configuration. Example Spack configurations are available
in a separate repository: [https://github.com/ukri-bench/system-configs]

### Manual build

- ADD: Describe (or link to) the manual build process for a systems where
  baseline performance has been measured.
  - Links to multiple sub-pages of instructions can be added if they are
    too long to fit on this page

## Running the benchmark

The benchmark can be run using ReFrame or manually. 

If you use ReFrame, then ReFrame will build the software, run the benchmark,
test for correctness, extract the performance/figure of merit (FoM) for you and
report them.

### Running using ReFrame

The ReFrame test configuration is available in the `reframe/` subdirectory.

ADD: Instructions on running ReFrame for this benchmark.

Note: to use ReFrame, you must have ReFrame installed on the system you are using and
a valid ReFrame system configuration. Example ReFrame configurations are available
in a separate repository: [https://github.com/ukri-bench/system-configs]

### Running manually

- ADD: Example of how to run the software (may include example job submission scripts
  in separate files in the repo)
- ADD: Example of how to test correctness
- ADD: Example of how to extract performance/FoM

## Example performance data

This section contains example performance data from selected HPC systems.

ADD: Example performance data

## License

This benchmark description and associated files are released under the MIT license.
