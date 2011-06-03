#!/bin/bash

# This is the staging script for a new build of WormBase.

# See for documentation
# http://wiki.wormbase.org/index.php/Updating_The_Development_Server

# This needs to be manually started. Alternatively, simply poll the Sanger FTP site.
RELEASE=$1

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf

export RSYNC_RSH=ssh
VERSION=$1

function alert() {
  msg=$1
  echo ""
  echo ${msg}
  echo ${SEPERATOR}
}


function failure() {
  msg=$1
  echo "  ---> ${msg}..."
  exit
}

function success() {
  msg=$1
  echo "  ${msg}."
}



# Pull in configuration variables shared across scripts
source ../../update.conf

RELEASE=$1
SPECIES=$2

if [ $SPECIES ]
then

    cd ${FTP_RELEASES_PATH}/${RELEASE}/species/${SPECIES}

    if [ $SPECIES == 'c_elegans' ]
    then
	cd /tmp
	cp ${FTP_RELEASES_PATH}/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.genomic.fa.gz ${SPECIES}-genomic.fa.gz
	gunzip -c ${SPECIES}.genomic.fa.gz | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > c_elegans.${RELEASE}.genomic.fa.gz
        gzip c_elegans.${RELEASE}.genomic.fa

	cd /home/tharis/projects/wormbase/website-admin/update/staging
        # Remove introns from the GFF
        ./helpers/process_celegans_gff.pl ${FTP_RELEASES_PATH}/${RELEASE}/species/${SPECIES}/.gff.gz

	bp_bulk_load_gff.pl --user ${MYSQL_USER} --pass ${MYSQL_PASS} --create --database c_elegans_${RELEASE} --fasta c_elegans.WS225.dna.fa.gz c_elegans.WS224GBrowse.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.protein_motifs.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.genetic_intervals.gff.gz


IF fasta
    ... build blast and blat

IF GFF
    ... build gbrowse


done




