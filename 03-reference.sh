#!/usr/bin/env bash

# Cluster configuration
#-------------------------------------------------------------------------------
#PBS -N RiceAssemblyDeNovo-BestStudent
#PBS -l nodes=1:ppn=16,walltime=24:00:00,vmem=250gb
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
AGDIR=/N/dc2/projects/brendelgroup/local/src/AlignGraph/AlignGraph
ACDIR=/N/dc2/projects/brendelgroup/local/src/PAGIT/ABACAS

export PATH=${AGDIR}:$PATH
export PATH=${ACDIR}:$PATH


# Sanity checks; if the script is going to fail, let's have it fail as soon as
# possible!
#-------------------------------------------------------------------------------
module load bowtie2/2.1.0
module load blat
module load ngsutils
module load java

which bowtie2         > /dev/null 2>&1 || echo "Error: cannot run Bowtie2"
which blat            > /dev/null 2>&1 || echo "Error: cannot run blat"
which fastqutils      > /dev/null 2>&1 || echo "Error: cannot run fastqutils"
which AlignGraph      > /dev/null 2>&1 || echo "Error: cannot run AlignGraph"
which abacas.1.3.1.pl > /dev/null 2>&1 || echo "Error: cannot run ABACAS"

[ -f all-1.fq.gz ] || echo "Error: cannot find reads 'all-1.fq.gz'"
[ -f all-2.fq.gz ] || echo "Error: cannot find reads 'all-2.fq.gz'"
if [ ! -f all-1.fq.gz ] || [ ! -f all-2.fq.gz ]; then
  exit 1
fi


# Procedure
#-------------------------------------------------------------------------------
set -eo pipefail

cd $WORKDIR

# Convert reads to Fasta format
fastqutils tofasta all-1.fq.gz | gzip -c > all-1.fa.gz &
fastqutils tofasta all-1.fq.gz | gzip -c > all-2.fa.gz &
wait

# Run AlignGraph
ls -1 *.contig GapFillerOutput/*.fa | xargs cat {} > seqs-gapfilled.fa
AlignGraph \
    --read1 all-1.fa.gz \
    --read2 all-2.fa.gz \
    --contig seqs-gapfilled.fa \
    --genome REF_CHROME.fa \
    --distanceLow 50 \
    --distanceHigh 1500 \
    --kMer 25 \
    --coverage 5 \
    --extendedContig extended-contigs.fa \
    --remainingContig remaining-contigs.fa

# Pseudomolecule construction with ABACAS
cat extended-contigs.fa remaining-contigs.fa > aligngraph-all-contigs.fa
abacas.1.3.1.pl \
    -r REF_CHROME.fa \
    -q aligngraph-all-contigs.fa \
    -p nucmer \
    -m -b -N -i 80 -l 200 \
    -o abacas-all-contigs
