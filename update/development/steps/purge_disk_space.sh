#!/bin/sh

# Clear out old files that are already mirrored to the main FTP site

FTP=/usr/local/ftp/pub/wormbase
GENOMES=("c_elegans c_briggsae c_japonica c_brenneri c_remanei p_pacificus b_malayi h_bacteriophora");

for GENOME in ${GENOMES}
do

    rm  -rf ${FTP}/genomes/${GENOME}/genome_feature_tables/GFF2/*
    rm  -rf ${FTP}/genomes/${GENOME}/genome_feature_tables/GFF3/*
    rm  -rf ${FTP}/genomes/${GENOME}/sequences/mrna/*
    rm  -rf ${FTP}/genomes/${GENOME}/sequences/ncrna/*
    rm  -rf ${FTP}/genomes/${GENOME}/sequences/dna/*
    rm  -rf ${FTP}/genomes/${GENOME}/sequences/protein/*

done

exit;
