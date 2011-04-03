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


for SPECIES in ${MYSQL_DATABASES} 
do	
    alert "Rsyncing ${SPECIES} onto ${NODE}..."

# C. elegans
gunzip c_elegans.${RELEASE}.dna.fa.gz
perl -p -i -e 's/CHROMOSOME_//g' c_elegans.${RELEASE}.dna.fa.gz
gzip c_elegans.${RELEASE}.dna.fa.gz

# Remove introns from the GFF
./process_celegans_gff.pl --file c_elegans.${RELEASE}.gff.gz

bp_bulk_load_gff.pl --user root --pass 3l3g@nz --create --database c_elegans_WS224 --fasta c_elegans.WS224.dna.fa.gz c_elegans.WS224GBrowse.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.protein_motifs.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.genetic_intervals.gff.gz


IF fasta
    ... build blast and blat

IF GFF
    ... build gbrowse


done




