#!/bin/sh

USER=$1

/usr/sbin/groupadd acedb
/usr/sbin/useradd -g acedb -d /usr/local/acedb acedb

# create a WormBase user and group and suitable directories
/usr/sbin/groupadd wormbase
/usr/sbin/useradd -g wormbase -d /home/wormbase wormbase
mkdir /home/wormbase
chown wormbase /home/wormbase
chgrp wormbase /home/wormbase

# Add the current user to the wormbase and acedb groups
/usr/sbin/usermod -a -G acedb,wormbase ${USER}

mkdir /usr/local/acedb
chown acedb:acedb /usr/local/acedb
chmod 2775 /usr/local/acedb

mkdir /usr/local/wormbase
chgrp wormbase /usr/local/wormbase
chmod 2775 /usr/local/wormbase

mkdir /usr/local/wormbase/logs
chgrp wormbase /usr/local/wormbase/logs
chmod 777 /usr/local/wormbase/logs

mkdir /usr/local/wormbase/cache
chmod 777 /usr/local/wormbase/cache
chown wormbase /usr/local/wormbase/*

mkdir /usr/local/wublast
chgrp wormbase /usr/local/wublast
chmod 2775 /usr/local/wublast

# Installing acedb
mkdir acedb ; cd acedb
wget \
ftp://ftp.sanger.ac.uk/pub/acedb/SUPPORTED/ACEDB-STATIC_serverLINUX.4.9.30.tar.gz
wget \
ftp://ftp.sanger.ac.uk/pub/acedb/SUPPORTED/ACEDB-STATIC_binaryLINUX.4.9.30.tar.gz
gunzip -c ACEDB-* | tar xvf -
mv ACEDB* ~${USER}/src/.
mkdir /usr/local/acedb/bin
chown acedb:acedb /usr/local/acedb/bin
mv * /usr/local/acedb/bin
chown root:root /usr/local/acedb/bin
