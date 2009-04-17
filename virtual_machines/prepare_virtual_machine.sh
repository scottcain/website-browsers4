#!/bin/sh

# Prepare a virtual machine for release
# This should be run from the HOST machine

VERSION=$1
DATE=$2

if [ ! "$VERSION" -a ! "$DATE" ]
then
  echo "Usage: $0 WSXXX YYYY.MM.DD"
  exit
fi



###############################################
# Set up a directory structure for mirroring
# to the FTP site
###############################################
cd /usr/local/vmx

# These will need to be rearranged later
mkdir ${VERSION}-databases
mkdir ${VERSION}


##################################
#  Fix the .vmx file for this release
##################################
#perl -p -i -e "s/WSVERSION/${VERSION}/g" wormbase-live/wormbase-core-centOS4.4-i386.vmx
#perl -p -i -e "s/WSDATE/${DATE}/g" wormbase-live/wormbase-core-centOS4.4-i386.vmx


##################################
# Register this VM
##################################
#vmware-cmd -s register /usr/local/vmx/wormbase-live/wormbase-core-centOS4.4-i386.vmx

##################################
# Set up new virtual disks
##################################
cd /usr/local/vmx

# The acedb disk
tar xzf empty_disks/50GB.tgz
mv 50GB ${VERSION}-databases/acedb

# The C. elegans GFF disk
tar xzf empty_disks/20GB.tgz
mv 20GB ${VERSION}-databases/c_elegans

# The disk containing various support DBs (ie BLAST)
tar xzf empty_disks/20GB.tgz
mv 20GB ${VERSION}-databases/support

# The autocomplete disk
tar xzf empty_disks/20GB.tgz
mv 20GB ${VERSION}-databases/autocomplete

# Other genomes (currently brugia, remanei)
tar xzf empty_disks/20GB.tgz
mv 20GB ${VERSION}-databases/other_species


# Create a symlink
cd /usr/local/vmx
rm -rf current_databases
ln -s ${VERSION}-databases current_databases
