#!/bin/sh

# This copies select files from the FTP site
# to brie6 to be served by the standard URLs mechanism.
export RSYNC_RSH=ssh

# Remote host
HOST=brie4.cshl.org
ROOT=/var/ftp/pub/wormbase/genomes

# This is the primary production node that hosts MT, main index, etc
PRODUCTIONHOST=brie6.cshl.org
DESTINATION=/usr/local/wormbase/databases/standard_urls

SPECIES=("c_elegans c_briggsae c_remanei c_japonica c_brenneri p_pristionchus b_malayi h_bacteriophora")
DIRS=("genome_feature_tables/GFF3 sequences")
for SPECIES in ${SPECIES}
do
   for DIR in ${DIRS}
   do
        mkdir -p ${DESTINATION}/${SPECIES}/${DIR}
        if rsync -Ca --exclude archive --delete ${HOST}:${ROOT}/${SPECIES}/${DIR}/ ${DESTINATION}/${SPECIES}/${DIR}
	then
             echo "successfully mirrored ${HOST}:${ROOT}/${SPECIES}/${DIR} to ${DESTINATION}"
        else
	    echo "mirroring failed ${HOST}:${ROOT}/${SPECIES}/${DIR} to ${DESTINATION}"
	fi
   done
done
