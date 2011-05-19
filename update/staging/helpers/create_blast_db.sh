#!/bin/bash

###############################
#
# BLAST databases: genomic
#
###############################

# Create nucleotide BLAST databases.
# Provided with a WSXXX release only,
# try and create databases for all species.

# Provided with a release and g_species, try
# to create a database for a single species.

# Assumes:
# 1. Fasta input is at 
#     /usr/local/ftp/pub/wormbase/releases/$RELEASE/species/$SPECIES/$SPECIES.$RELEASE.genomic.fa.gz


# Pull in configuration variables shared across scripts
source ../../update.conf

RELEASE=$1
TYPE=$2
SPECIES=$3

if [ ! "$RELEASE" ]
then
  echo "Usage: $0 WSXXX [nucleotide|protein] [species]"
  exit
fi

if [ $TYPE == 'nucleotide' ]
then 
    PARAMS=F
    INPUT_FILE=genomic.fa
    TAG=genomic
else
    PARAMS=T
    INPUT_FILE=peptide.fa
    TAG=protein
fi

if [ $SPECIES ]
then
    cd ${FTP_RELEASES_PATH}/${RELEASE}/species/$SPECIES
    if [ -e ${SPECIES}.${RELEASE}.genomic.fa.gz ]
    then
	cd ${SUPPORT_DATABASES_DIR}/${RELEASE}/blast
	mkdir ${SPECIES}
	cd ${SPECIES}
	gunzip -c ${FTP_RELEASES_DIR}/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.genomic.fa.gz > genomic.fa
	
	# Press it into a blastdb
	${BLAST_EXEC} -p ${PARAMS} -t '${SPECIES} ${TAG} ${RELEASE}' -i ${INPUT_FILE}
    fi
else

   # Try to create databases for all species
    cd ${FTP_RELEASES_DIR}/${RELEASE}/species/$SPECIES
    for SPECIES in *
    do
	if [ -e ${SPECIES}.${RELEASE}.genomic.fa.gz ]
	then
	    cd ${SUPPORT_DATABASES_DIR}/${RELEASE}/blast
	    mkdir ${SPECIES}
	    cd ${SPECIES}
	    gunzip -c ${FTP_RELEASES_DIR}/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.genomic.fa.gz > genomic.fa
	    
	# Press it into a blastdb
	    ${BLAST_EXEC} -p ${PARAMS} -t '${SPECIES} ${TAG} ${RELEASE}' -i ${INPUT_FILE}
	fi
    done
fi