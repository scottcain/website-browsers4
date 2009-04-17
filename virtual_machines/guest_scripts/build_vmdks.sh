#!/bin/bash

# This script is used to prepare a virtual machine for release
# from WITHIN THE GUEST OS!

# It creates a series of virtual disks, assuming that their path
# is ../databases from the .vmx file:
#   vmx/VERSION/*.vmx
#   vmx/databases/VERSION
#   vmx/databases/archive

# It must be run with root privileges

VERSION=$1
#DO_ACE=1
#DO_DATABASES=1
#DO_AUTOCOMPLETE=1
DO_ELEGANS_GFF=1
USER=todd
HOST=brie3.cshl.org

export RSYNC_RSH=ssh

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

# Unmount first, just in case
# This will fail silently
sudo umount /dev/sdb1
sudo umount /dev/sdc1
sudo umount /dev/sdd1
sudo umount /dev/sde1
sudo umount /dev/sdf1
#sudo umount /dev/sdg1


###################################
# Acedb
###################################
if [ $DO_ACE ]
then
  echo ""
  echo "================================";
  echo "Installing Acedb elegans_{$VERSION}..."
  cd /usr/local/acedb

  # Clear out old versions
  rm -rf elegans*
  mkdir elegans
  sudo mount -t ext3 /dev/sdb1 elegans
  # These permissions should probably be fixed in the vmdk itself
  sudo chown acedb:acedb elegans
  sudo chmod 2775 elegans
  cd elegans
  if rsync -COav --exclude=serverlog.wrm --exclude=log.wrm --exclude=readlocks ${USER}@${HOST}:/usr/local/acedb/elegans_${VERSION}/ .
  then
    echo "   successfully transfered acedb ${VERSION}..."
  else
    echo "--->Transferring acedb FAILED!"
    exit
  fi
  rm -rf database/readlocks
  rm -rf database/log.wrm
  rm -rf database/serverlog.wrm
  cd ..
  sudo chown -R acedb:acedb elegans
  echo "   installation of acedb complete"
fi


###################################
# BLAST / BLAT databases
###################################
if [ $DO_DATABASES ]
then
  echo ""
  echo "================================";
  echo "Installing databases..."
  cd /usr/local/wormbase
  # Purge old databases
  rm -rf databases
  mkdir databases
  sudo mount -t ext3 /dev/sdc1 databases
  sudo chown wormbase:wormbase databases
  sudo chmod 2775 databases

  cd databases
  if rsync -COav ${USER}@${HOST}:/usr/local/wormbase/databases/${VERSION} .
  then
    echo "   successfully transfered support databases..."
  else
    echo "--->Transferring databases FAILED!"
    exit
  fi
fi
#sftp brie3:/usr/local/wormbase/databases/* .
#sftp brie3:/usr/local/wormbase/databases/blast/c_briggsae/cb3 .
#sftp brie3:/usr/local/wormbase/databases/blast/c_briggsae/${VERSION} .
#sftp brie3:/usr/local/wormbase/databases/blastc_elegans/${VERSION} .


###################################
# Autocomplete
###################################
if [ $DO_AUTOCOMPLETE ]
  then
  echo ""
  echo "================================";
  echo "Installing autocomplete mysql database..."
  cd /usr/local/mysql/data
  sudo rm -rf autocomplete*
  mkdir autocomplete
  sudo mount -t ext3 /dev/sdd1 autocomplete
  sudo chown -R mysql:mysql autocomplete
  sudo chmod 2775 autocomplete
  cd autocomplete
  if rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/autocomplete_${VERSION}/ .
  then
    echo "   successfully transferred autocomplete mysql database..."
  else
    echo "--->Transferring autocompletedb FAILED!"
    exit
  fi

  cd ..
##  rm -rf autocomplete
##  ln -s autocomplete_${VERSION} autocomplete
  sudo chown -R mysql:mysql autocomplete
  sudo chmod 2775 autocomplete
  echo "   installation of autocomplete mysql database complete..."
fi


###################################
# C. elegans GFF
###################################
if [ $DO_ELEGANS_GFF ]
then
  echo ""
  echo "================================";
  echo "Installing C. elegans mysql GFF databases..."
  cd /usr/local/mysql/data
  sudo rm -rf elegans*
  mkdir elegans
  sudo mount -t ext3 /dev/sde1 elegans
  sudo chown -R mysql:mysql elegans
  sudo chmod 2775 elegans
  cd elegans
  if rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/elegans_${VERSION}/ .
  then
    echo "   successfully transferred elegans GFF databases..."
  else
    echo "--->Transferring elegans GFF FAILED!"
    exit
  fi

  cd /usr/local/mysql/data
  ##rm -rf elegans
  ##ln -s elegans_${VERSION} elegans

  # These are nested in the virtual disk. I hope mysql doesnt choke on this!
  cd elegans
  rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/elegans_pmap_${VERSION}/ elegans_pmap
  rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/elegans_gmap_${VERSION}/ elegans_gmap

  cd /usr/local/mysql/data
  rm -rf elegans_pmap
  ln -s elegans/elegans_pmap elegans_pmap

  rm -rf elegans_gmap
  ln -s elegans/elegans_gmap elegans_gmap

  cd /usr/local/mysql/data
  sudo chown -R mysql:mysql elegans
  sudo chmod 2775 elegans elegans/elegans_pmap elegans/elegans_gmap
  echo "   installation of C. elegans GFF databases complete..."
fi


###########################################
# Other species: briggsae, brugie, remanei
###########################################
cd /usr/local/mysql/data
echo ""
echo "================================";
echo "Installing GFF databases for other species..."
sudo rm -rf briggsae* brugia* remanei* brenneri*
mkdir other_species
sudo mount -t ext3 /dev/sdf1 other_species
sudo chown -R mysql:mysql other_species
sudo chmod 2775 other_species
cd other_species

if rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/briggsae_${VERSION} .
then
  echo "   transfer of C. briggsae GFF database complete..."
else
  echo "--->Transferring briggsae GFF FAILED!"
  exit
fi

if rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/brugia_bma1 .
then
  echo "   transfer of B. malayi GFF database complete..."
else
  echo "--->Transferring B. malayi GFF FAILED!"
  exit
fi


if rsync -COav ${USER}@${HOST}:/usr/local/mysql/data/remanei_preliminary .
then
  echo "   transfer of C. remanei GFF database complete..."
else
  echo "--->Transferring C. remanei GFF FAILED!"
  exit
fi

cd /usr/local/mysql/data
sudo chown -R mysql:mysql other_species
sudo chmod 2775 other_species
ln -s other_species/briggsae_${VERSION} briggsae
ln -s other_species/brugia_bma1 brugia
ln -s other_species/remanei_preliminary remanei
echo "   installation of other_species GFF databases complete..."

