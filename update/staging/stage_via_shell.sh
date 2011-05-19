#!/bin/bash

# Pull in my configuration variables shared across scripts
source ../update.conf

RELEASE=$1
cd $FTP_RELEASES_DIR

####################################
#
#     MIRROR
#  
####################################
helpers/mirror_new_release.sh ${RELEASE}

####################################
#
#     ACEDB
#  
####################################

helpers/unpack_acedb.sh ${RELEASE}


###############################
#
# CREATE DIRECTORIES
#
###############################

cd ${WORMBASE_ROOT}
mkdir databases
cd databases
mkdir ${RELEASE}
cd ${RELEASE}
mkdir blast blat epcr ontology tiling_array interaction orthology position_matrix gene


###############################
#
# BLAST databases: genomic
#
###############################

helpers/create_blastdb.sh ${RELEASE} nucleotide

###############################
#
# BLAST databases: protein
#
###############################

helpers/create_blastdb.sh ${RELEASE} protein

###############################
#
# BLAST databases: ESTs and GENEs
#
###############################

# NOT HANDLED IN .sh YET.


###############################
#
# Load Genomic GFF databases
#
###############################
helpers/load_genomic_gff_databases.sh