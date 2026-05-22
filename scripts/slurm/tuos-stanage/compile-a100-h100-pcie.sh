#!/bin/bash
#SBATCH --time=00:30:00

# Must compile for the GPU nodes on the GPU nodes for the correct CPU arch. The specific GPU doesn't currently matter.
#SBATCH --partition=gpu
#SBATCH --qos=gpu
#SBATCH --gres=gpu:1

# 12 CPU cores (1/4th of an a100 node) and 1 GPUs worth of memory < 1/4th of the node)
#SBATCH --cpus-per-task=12
#SBATCH --mem=82G

# A100 module environment is active on the A100 nodes automatically now, load appropriate modules
module load GCC/12.3.0
module load CUDA/12.4.0
module load CMake/3.26.3-GCCcore-12.3.0

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

set -e

# navigate into the root directory.
cd $PROJECT_ROOT

# Configure cmake for A100 and H100 GPUs (SM_80;SM_90) in Release without seatbelts
export CUDAHOSTCXX=$(which g++)
cmake -S . -B build-a100-h100-pcie -DCMAKE_CUDA_ARCHITECTURES="80;90" -DCMAKE_BUILD_TYPE=Release -DFLAMEGPU_SEATBELTS=OFF -DFLAMEGPU_SHARE_USAGE_STATISTICS=OFF -DCMAKE_SKIP_RPATH=ON

# Compile the code using all available processors.
cmake --build build-a100-h100-pcie -j `nproc` --verbose

