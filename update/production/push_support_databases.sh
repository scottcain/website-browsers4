#!/bin/bash

# Pull in legacy databases into the current databases/version dir
# Then sync this to the blast db

export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

SUPPORT_DB_DIR=/usr/local/wormbase/databases
SUPPORT_DB_NODES=("blast.wormbase.org aceserver.cshl.edu gene.wormbase.org 
                  vab.wormbase.org brie6.cshl.edu");
#SUPPORT_DB_NODES=("blast");

# The repository of archived databases
REPOSITORY=brie4.cshl.org

# Internal targets for archived releases
BLAST_DIR=${SUPPORT_DB_DIR}/${VERSION}/blast
BLAT_DIR=${SUPPORT_DB_DIR}/${VERSION}/blat

SEPERATOR="==========================================="

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


## Here's an odd function that doesn't really belong here.
## Let's tar up C. elegans and make it available
#alert "Tarring current release of C. elegans..."
#cd ${BLAST_DIR}
#tar czf ${VERSION}.tgz c_elegans
#scp ${VERSION}.tgz ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/elegans/prebuilt_databases/blast/.
#rm -rf ${VERSION}.tgz


## THE SUPPORT DATABASES
#alert "Fetching c_briggsae blast databases from ${REPOSITORY}..."
#cd ${BLAST_DIR}
#mkdir c_briggsae
#cd c_briggsae
## CB25 NCBI blast
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/briggsae/prebuilt_databases/blast/cb25-ncbi-blast.tgz .
#tar xzf cb25-ncbi-blast.tgz
#mv cb25-ncbi-blast cb25
#rm -rf cb25-ncbi-blast.tgz
#
### CB3 NCBI blast
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/briggsae/prebuilt_databases/blast/cb3-ncbi-blast.tgz .
#tar xzf cb3-ncbi-blast.tgz
#mv cb3-ncbi-blast cb3
#rm -rf cb3-ncbi-blast.tgz
#
#
#alert "Fetching c_briggsae blat databases from ${REPOSITORY}..."
#cd ${BLAT_DIR}
#mkdir c_briggsae
#cd c_briggsae
## CB3
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/briggsae/prebuilt_databases/blat/cb3.tgz .
#tar xzf cb3.tgz
#rm -rf cb3.tgz
#
## CB25
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/briggsae/prebuilt_databases/blat/cb25.tgz .
#tar xzf cb25.tgz
#rm -rf cb25.tgz


#alert "Fetching c_brenneri blast databases from ${REPOSITORY}..."
#cd ${BLAST_DIR}
#mkdir c_brenneri
#cd c_brenneri
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/brenneri/prebuilt_databases/blast/2007_01_draft_assembly.tgz .
#tar xzf 2007_01_draft_assembly.tgz
#rm -rf 2007_01_draft_assembly.tgz

#alert "Fetching c_remanei blast databases from ${REPOSITORY}..."
#cd ${BLAST_DIR}
#mkdir c_remanei
#cd c_remanei
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/remanei/prebuilt_databases/blast/2005_08_20_assembly-ncbi-blast.tgz .
#tar xzf 2005_08_20_assembly-ncbi-blast.tgz
#mv 2005_08_20_assembly-ncbi-blast 2005_08_20_assembly
#rm -rf 2005_08_20_assembly-ncbi-blast.tgz

#alert "Fetching b_malayi blast databases from ${REPOSITORY}..."
#cd ${BLAST_DIR}
#mkdir c_brugia
#cd c_brugia
#scp ${REPOSITORY}:/var/ftp/pub/wormbase/genomes/brugia/prebuilt_databases/blast/2007.09-bma1.tgz .
#tar xzf 2007.09-bma1.tgz
#mv 2007.09-bma1 bma1
#rm -rf 2007.09-bma1*

# Sync the currnet database directory to the support hosts
alert "Pushing the support databases dir on database nodes..."
for NODE in ${SUPPORT_DB_NODES}
do
  alert " ${NODE}:"
  if [ "${NODE}" == "blast.wormbase.org" ]
  then
  	if rsync --progress -Cavv --exclude *bak* \
	 	${SUPPORT_DB_DIR}/${VERSION} ${NODE}:${SUPPORT_DB_DIR}
 	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   else
	if rsync --progress -Ca --exclude *bak* \
		--exclude blast \
		--exclude blat \
		${SUPPORT_DB_DIR}/${VERSION} ${NODE}:${SUPPORT_DB_DIR}
  	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   fi

done

exit;

