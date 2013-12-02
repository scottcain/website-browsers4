#!/bin/bash

# Pull in my configuration variables shared across scripts
source ../../update.conf

RELEASE=$1

####################################
#
#     UNPACK ACEDB
#  
####################################
cd ${ACEDB_ROOT}
mkdir wormbase_${RELEASE}
chgrp ${ACEDB_USER}:${ACEDB_GROUP} wormbase_${RELEASE}
chmod 2775 wormbase_${RELEASE}
cd wormbase_${RELEASE}
for i in ${FTP_RELEASE_DIR}/${RELEASE}/acedb/database*.tar.gz
do 
    tar -xvzf $i
done
chown -R acedb:acedb *
chmod g+ws database

# Customize AceDB.
chmod ug+rw wspec/*.wrm
for i in ${WORMBASE_ROOT}/website/classic/wspec/*.wrm
do
    cp $i wspec/.
done

