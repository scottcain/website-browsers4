#!/bin/bash

VERSION=$1
DATE=$2

export RSYNC_RSH=ssh

if [ ! "$VERSION" -a ! "$DATE" ]
then
  echo "Usage: $0 WSXXX YYYY.MM.DD"
  exit
fi

cd /usr/local/vmx

cd ${VERSION}-databases

DATABASES=("c_elegans support acedb other_species autocomplete")

for DB in ${DATABASES}
do
  if tar czf ${DB}.tgz ${DB}
  then
    /usr/local/vmx/do_md5.pl /usr/local/vmx/${VERSION}-databases/${DB}.tgz
    rm -rf ${DB}
  fi
done


# MAKE SURE THE VMX IS SHUT DOWN FIRST!!

cd /usr/local/vmx
mkdir wormbase-${VERSION}.${DATE}
mv ${VERSION}-databases wormbase-${VERSION}.${DATE}/.
cp -r wormbase-live-server wormbase-${VERSION}.${DATE}/wormbase-${VERSION}.${DATE}

# Create the symlink.  The databases should be decompressed in the same directory
cd wormbase-${VERSION}.${DATE}
ln -s ${VERSION}-databases current_databases
cd ../
if tar czf wormbase-${VERSION}.${DATE}.tgz wormbase-${VERSION}.${DATE}
then
  /usr/local/vmx/do_md5.pl /usr/local/vmx/wormbase-${VERSION}.${DATE}.tgz
  rm -rf wormbase-${VERSION}.${DATE}
fi


# Send it on over to the FTP site
cd /usr/local/vmx
rsync -Cav ${VERSION} brie4:/var/ftp/pub/wormbase/people/tharris/vmx/.
