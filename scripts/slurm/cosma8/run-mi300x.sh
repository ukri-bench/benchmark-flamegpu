#!/bin/bash
#SBATCH --time=1:00:00
#SBATCH --account=do018
#SBATCH --partition=mi300x
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=12 # 1/8th of 96 cores
#SBATCH --mem=194G # 1 GPUs worth with change

# Example slurm job submission script used to run on the mi300x nodes in cosma8's d018 partition
# Compiled manually using CMake into `build-gfx942`

# No module loads were required on the mi300x node (when this was written)

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

# navigate into the `build` directory.
cd $PROJECT_ROOT
mkdir -p data
cd build-gfx942

# Output the node this was executed on
echo "HOSTNAME=${HOSTNAME}"

# Output some GPU information into the Log
amd-smi

# Run the executable.
./bin/Release/benchmark-flamegpu -o ../data/cosma8-mi300x-${SLURM_JOB_ID}.json
