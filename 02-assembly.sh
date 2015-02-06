#!/usr/bin/env bash

# Cluster configuration
#-------------------------------------------------------------------------------
#PBS -N RiceAssemblyDeNovo-BestStudent
#PBS -l nodes=1:ppn=32,walltime=72:00:00,vmem=500gb
#PBS -j oe
#PBS -m abe
#PBS -q shared
#PBS -M beststudent@indiana.edu


# Script configuration
#-------------------------------------------------------------------------------
USERNAME=beststudent
RUN=run01    # Use the same value you used for read prep step

# You shouldn't need to adjust the remaining settings
WORKDIR=/N/dc2/scratch/${USERNAME}/rice-assembly/${RUN}
KGDIR=/N/dc2/projects/brendelgroup/local/src/kmergenie-1.6950
GFDIR= # ???

export PATH=${KGDIR}:$PATH
export PATH=${GFDIR}:$PATH


# Sanity checks; if the script is going to fail, let's have it fail as soon as
# possible!
#-------------------------------------------------------------------------------
module load soapdenovo/r240
module load python
module load R

which kmergenie        > /dev/null 2>&1 || echo "Error: cannot run kmergenie"
which SOAPdenovo-63mer > /dev/null 2>&1 || echo "Error: cannot run SOAPdenovo"
which GapFiller.pl     > /dev/null 2>&1 || echo "Error: cannot run GapFiller"
which python           > /dev/null 2>&1 || echo "Error: cannot run Python"
which Rscript          > /dev/null 2>&1 || echo "Error: cannot run R"

[ -f all-1.fq.gz ] || echo "Error: cannot find reads 'all-1.fq.gz'"
[ -f all-2.fq.gz ] || echo "Error: cannot find reads 'all-2.fq.gz'"
if [ ! -f all-1.fq.gz ] || [ ! -f all-2.fq.gz ]; then
  exit 1
fi


# Procedure
#-------------------------------------------------------------------------------
set -eo pipefail

cd $WORKDIR

# Determine best value of K to use for de novo assembly
ls all-*.fq.gz > kmergenie-filelist.txt
kmergenie -l 17 -k 63 -s 4 -t 32 kmergenie-filelist.txt \
    | tee kmergenie-stdout.txt \
    | tail -n 1 \
    > BEST_KMER.txt
K=$(cat BEST_KMER.txt)

# Run de novo assembly
SOAPdenovo-63mer all -s soap.config -K $K -R -p 32 -o denovoassembly \
    1> assembly.log \
    2> assembly.err

# Do gap filling; use "ls | xargs" so we don't have to know the filename
ls -1  *.scafSeq \
    | xargs GapFiller.pl -l gapfill.config -m 36 -o 2 -r 0.7 -n 10 -d 50 -t 10 \
                         -g 0 -T 32 -i 5 -b GapFillerOutput -s {}
