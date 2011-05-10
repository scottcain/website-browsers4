#!/bin/bash

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

VERSION=$1
SINGLE_SPECIES=$2

if [ ! "$SINGLE_SPECIES" ]
then
    SPECIES=${SINGLE_SPECIES}
fi


if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

FTP_ROOT=/usr/local/ftp/pub/wormbase
SPECIES_ROOT=${FTP_ROOT}/species
RELEASE_ROOT=${FTP_ROOT}/releases
RELEASES=../../../

function create_symlinks_to_versioned_files() {
    for THIS_SPECIES in ${SPECIES}
    do
	alert "Symlinking current ${THIS_SPECIES} to its source file in the releases/ directory..."
    
# Link GFF2/GFF3
    cd ${SPECIES_ROOT}/gff
    if [ -e "../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.gff.gz" ]
    then
	ln -s ../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.gff2.gz ${THIS_SPECIES}.${VERSION}.gff2.gz
    fi

    if [ -e "../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.gff3.gz" ]
    then
	ln -s ../../../releases/${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.gff3.gz ${THIS_SPECIES}.${VERSION}.gff3.gz
    fi

# Sequences: dna
    cd ${SPECIES_ROOT}/sequence
    ln -s ../../../releases/${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.dna.fa.gz.gz ${THIS_SPECIES}.${VERSION}.dna.fa.gz

    # Sequences: protein. Needs to be fixed by Hinxton


}