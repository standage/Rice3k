#!/usr/bin/env bash

# Cluster configuration
#-------------------------------------------------------------------------------
#PBS -N RiceAssemblyReadPrep-BestStudent
#PBS -l nodes=1:ppn=16,walltime=12:00:00,vmem=250gb
#PBS -j oe
#PBS -m abe
#PBS -q shared
#PBS -M beststudent@indiana.edu


# Script configuration
#-------------------------------------------------------------------------------
ACCESSIONS="ERR605259 ERR605260 ERR605261 ERR605262"
USERNAME=beststudent
RUN=run01    # If want to start over with a clean directory, just change this
MINQUAL=28   # Quality threshold for trimming reads off the ends of the read
MINLENGTH=40 # Reads shorter than this after trimming will be discarded

# You shouldn't need to adjust the remaining settings
WORKDIR=/N/dc2/scratch/${USERNAME}/rice-assembly/${RUN}
TRIMDIR=/N/dc2/projects/brendelgroup/local/src/Trimmomatic-0.33
TRIMJAR=${TRIMDIR}/trimmomatic-0.33.jar
ADPTRS=${TRIMDIR}/adapters/all-PE.fa


# Sanity checks; if the script is going to fail, let's have it fail as soon as
# possible!
#-------------------------------------------------------------------------------
module load java
module load fastqc

which java   > /dev/null 2>&1 || echo "Error: cannot run Java"
which fastqc > /dev/null 2>&1 || echo "Error: cannot run FastQC"
which wget   > /dev/null 2>&1 || echo "Error: cannot run wget"

[ -f $TRIMJAR ] || echo "Error: cannot find Trimmomatic"
[ -f $ADPTRS  ] || echo "Error: cannot find Illumina adapter file"
if [ ! -f $TRIMJAR ] || [ ! -f $ADPTRS ]; then
  exit 1
fi


# Procedure
#-------------------------------------------------------------------------------
set -eo pipefail

mkdir -p $WORKDIR
cd $WORKDIR

for acc in $ACCESSIONS
do
  prefix=$(echo $acc | cut -c 1-6)
  ftpbase="ftp://ftp.sra.ebi.ac.uk/vol1/fastq"

  # Download reads (if necessary), do pre-trimming quality assessment
  for end in 1 2
  do
    filename=${acc}_${end}.fastq.gz
    [ -f ${filename} ] || wget ${ftpbase}/${prefix}/${acc}/${filename}
    fastqc $filename
  done

  # Adapter removal and quality trimming with Trimmomatic
  java -jar ${TRIMJAR} PE \
       -phred33 \
       -threads 16 \
       ${acc}_1.fastq.gz \
       ${acc}_2.fastq.gz \
       ${acc}_clean_1.fq.gz \
       ${acc}_clean_unpaired_1.fq.gz \
       ${acc}_clean_2.fq.gz \
       ${acc}_clean_unpaired_2.fq.gz \
       ILLUMINACLIP:${ADPTRS}:2:30:15 \
       SLIDINGWINDOW:6:${MINQUAL} \
       LEADING:${MINQUAL} \
       TRAILING:${MINQUAL} \
       MINLEN:${MINLENGTH}

  # Post-trimming quality assessment
  for end in 1 2
  do
    filename=${acc}_clean_${end}.fq.gz
    fastqc $filename
  done
done

# Concatenate all the data files together
for acc in $ACCESSIONS
do
  gunzip -c ${acc}_clean_1.fq.gz >> all-1.fq
  gunzip -c ${acc}_clean_2.fq.gz >> all-2.fq
done
gzip all-1.fq &
gzip all-2.fq &
wait
