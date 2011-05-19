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



# Iterate over all available species checking
# to see if there are files available for it
# for each release.

function link_gff2 {    

    mkdir -p ${FTP_SPECIES_ROOT}/${SPECIES}/gff
    if [ -e "${FTP_RELEASE_ROOT}/WS${RELEASE}/species/${SPECIES}/${SPECIES}.WS${RELEASE}.gff2.gz" ]
    then
	cd ${FTP_SPECIES_ROOT}/${SPECIES}/gff
	ln -s ../../../releases/WS${RELEASE}/species/${SPECIES}/${SPECIES}.WS${RELEASE}.gff2.gz ${SPECIES}.WS${RELEASE}.gff2.gz	    
	RETURN=$RELEASE
    fi	
}

function link_gff3() {
	if [ -e "${FTP_RELEASE_ROOT}/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.gff3.gz" ]
	then
	    cd ${FTP_SPECIES_ROOT}/${SPECIES}/gff
	    ln -s ../../../releases/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.gff3.gz ${SPECIES}.${RELEASE}.gff3.gz
	fi

	cd ${FTP_SPECIES_ROOT}/${SPECIES}
	ln -s ../../releases/${RELEASE}/species/${SPECIES}/${SPECIES}.${RELEASE}.

}

cd ${FTP_SPECIES_ROOT}
for SPECIES in *
do

    alert "Symlinking ${SPECIES} to source files in the releases/ directory..."

    cd ${FTP_RELEASE_ROOT}    
    for WSVERSION in WS*
    do
	RELEASE=`expr match "${this_link}" '.*_\(WS...\)'`
	link_gff2 $SPECIES $RELEASE	
    done
done
exit


	

    

    
# Sequences: dna
    cd ${SPECIES_ROOT}/sequence/genomic
    if [ -e "../../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic.fa.gz" ]
    then
	ln -s ../../../../releases/${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic.fa.gz ${THIS_SPECIES}.${VERSION}.genomic.fa.gz
    fi

    if [ -e "../../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic_softmasked.fa.gz" ]
    then
	ln -s ../../../../releases/${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic_masked.fa.gz ${THIS_SPECIES}.${VERSION}.genomic_masked.fa.gz
    fi

    if [ -e "../../../../${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic_softmasked.fa.gz" ]
    then
	ln -s ../../../../releases/${VERSION}/species/${THIS_SPECIES}/${THIS_SPECIES}.${VERSION}.genomic_masked.fa.gz ${THIS_SPECIES}.${VERSION}.genomic_masked.fa.gz
    fi
    
    # Sequences: protein. Needs to be fixed by Hinxton


}