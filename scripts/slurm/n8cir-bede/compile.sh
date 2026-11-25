#!/bin/bash
#SBATCH --account=bdshe03
#SBATCH --time=00:30:00
#SBATCH --partition=ghlogin
# Request a reasonable number of cores for faster compilation, without using the full node.
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G

module load gcc/14.2 
module load cuda/13.1.1 
module load cmake/3.30.5 

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

set -e

# navigate into the root directory.
cd $PROJECT_ROOT

# Configure cmake for H100 GPUs (SM_90) in Release without seatbelts u
export CUDAHOSTCXX=$(which g++)
cmake -S . -B build-cu131 -DCMAKE_CUDA_ARCHITECTURES=90 -DCMAKE_BUILD_TYPE=Release -DFLAMEGPU_SEATBELTS=OFF -DFLAMEGPU_SHARE_USAGE_STATISTICS=OFF -DCMAKE_SKIP_RPATH=ON

# Compile the code using all available processors.
cmake --build build-cu131 -j `nproc` --verbose

