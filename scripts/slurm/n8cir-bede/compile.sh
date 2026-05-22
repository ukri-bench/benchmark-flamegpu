#!/bin/bash
#SBATCH --account=bdshe03
#SBATCH --time=00:30:00
#SBATCH --partition=ghlogin

# 12 CPU cores (1/4th of an a100 node) and 1 GPUs worth of memory < 1/4th of the node)
#SBATCH --cpus-per-task=12
#SBATCH --mem=82G

module load gcc/14.2 
module load cuda/13.1.1 
module load cmake/3.30.5 

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

set -e

# navigate into the root directory.
cd $PROJECT_ROOT

# Configure cmake for A100 and H100 GPUs (SM_80;SM_90) in Release without seatbelts
export CUDAHOSTCXX=$(which g++)
cmake -S . -B build-cu131 -DCMAKE_CUDA_ARCHITECTURES=90 -DCMAKE_BUILD_TYPE=Release -DFLAMEGPU_SEATBELTS=OFF -DFLAMEGPU_SHARE_USAGE_STATISTICS=OFF -DCMAKE_SKIP_RPATH=ON

# Compile the code using all available processors.
cmake --build build-cu131 -j `nproc` --verbose

