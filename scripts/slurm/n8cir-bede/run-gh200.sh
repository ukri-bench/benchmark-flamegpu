#!/bin/bash
#SBATCH --account=<account>  # Replace with a valid account name
#SBATCH --time=1:00:00
#SBATCH --partition=gh
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
# No need for an exclusive flag, 1 GPU per node GH200 node in N8CIR Bede

module load gcc/14.2 
module load cuda/13.1.1 
module load cmake/3.30.5 

# Set the location of the project root relative to this script
PROJECT_ROOT=../../..

# navigate into the `build` directory.
cd $PROJECT_ROOT
mkdir -p data
cd build-cu131

# Output the node this was executed on
echo "HOSTNAME=${HOSTNAME}"

# Output some GPU information into the Log
nvidia-smi

# Run the executable.
./bin/Release/benchmark-flamegpu -o ../data/n8cir-bede-gh200-${SLURM_JOB_ID}.json

