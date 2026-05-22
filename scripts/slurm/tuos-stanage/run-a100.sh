#!/bin/bash
#SBATCH --time=1:00:00
#SBATCH --partition=gpu
#SBATCH --qos=gpu
#SBATCH --gres=gpu:1

# 12 CPU cores (1/4th of the node) and 1 GPUs worth of memory < 1/4th of the node)
# This could probably be a single CPU...
#SBATCH --cpus-per-task=12
#SBATCH --mem=82G

# A100 module environment is active on the A100 nodes automatically now, load appropriate modules
module load GCC/12.3.0
module load CUDA/12.4.0

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

# navigate into the `build` directory.
cd $PROJECT_ROOT
mkdir -p data
cd build-a100-h100-pcie

# Output the node this was executed on
echo "HOSTNAME=${HOSTNAME}"

# Output some GPU information into the Log
nvidia-smi

# Run the executable.
./bin/Release/benchmark-flamegpu -o ../data/tuos-stanage-a100-sxm4-${SLURM_JOB_ID}.json
