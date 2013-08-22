#!/bin/bash

# This is a script to migrate staged GFF databases
# to our RDS endpoint.

# For this to work, it will probably be necessary to update mysql
# (/etc/my.cnf) to write to a tmpdir with higher capacity.
# I'm using /mnt/ephemeral1

#declare -a dbs=(dbname1 dbname2 dbname3 dbname4);
# This list should be discoverable and  should use the g_species_BPID_WSXXX format
declare -a dbs=(c_elegans);

# Your RDS endpoint
RDS_ENDPOINT=mysql.wormbase.org
RDS_USER=wormbase
RDS_PASSWORD=sea3l3ganz

SOURCE_HOST=localhost
SOURCE_USER=root
SOURCE_PASS=3l3g@nz

TMPDIR=/mnt/ephemeral1/database_dumps
mkdir -p $TMPDIR

j=0
while [ $j -lt 1 ];
# 4 is the number of dbs
do
    echo "Dumping ${dbs[$j]} DB"
    echo "    Command is:"
    echo "    mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${dbs[$j]}` > $TMPDIR/`echo ${dbs[$j]}`.sql"

    time mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${dbs[$j]}` > $TMPDIR/`echo ${dbs[$j]}`.sql

    echo "Adding optimizations to ${dbs[$j]}"
    awk 'NR==1{$0="SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;\n"$0}1' $TMPDIR/`echo ${dbs[$j]}`.sql >> $TMPDIR/`echo ${dbs[$j]}`X.sql
    mv $TMPDIR/`echo ${dbs[$j]}`X.sql $TMPDIR/`echo ${dbs[$j]}`.sql
    echo "SET unique_checks=1; SET foreign_key_checks=1; COMMIT;" >> $TMPDIR/`echo ${dbs[$j]}`.sql
    echo "Creating ${dbs[$j]} on RDS host $RDS_ENDPOINT"
#    mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD -e 'create database ${dbs[$j]}

    echo "Copy ${dbs[$j]} into RDS"
    time mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD `echo ${dbs[$j]}` < /$TMPDIR/`echo ${dbs[$j]}`.sql &
    
    j=$(($j+1))
done
