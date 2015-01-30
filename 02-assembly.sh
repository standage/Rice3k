#!/usr/bin/env bash

# Cluster configuration
#-------------------------------------------------------------------------------
#PBS -N RiceAssemblyReadPrep-BestStudent
#PBS -l nodes=1:ppn=32,walltime=48:00:00,vmem=500gb
#PBS -j oe
#PBS -m abe
#PBS -q shared
#PBS -M beststudent@indiana.edu