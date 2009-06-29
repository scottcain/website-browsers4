#!/bin/bash

# Purge old releases from backend machines

VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

ACEDB_DIRECTORY=/usr/local/wormbase/acedb
REMOTE_MYSQL_DATA_DIRECTORY=/usr/local/mysql/data
NODES=`cat conf/nodes_all.conf`

MYSQL_DATABASES=(elegans elegans_gmap elegans_pmap autocomplete briggsae)

BASE=`expr "${VERSION}" : 'WS\(...\)'`


for NODE in ${NODES}
  do
  echo ""
  echo "==========================================="
  echo " Purging ${NODE}..."
# Kinda silly
  for ((i=170;i<BASE;i++))
    do
    for DATABASE in ${MYSQL_DATABASES}
      do
      if ssh ${NODE} "rm -rf ${REMOTE_MYSQL_DATA_DIRECTORY}/${DATABASE}_WS${i}"
	  then
	  echo " Successfully deleted ${DATABASE_WS${i} from ${NODE}..."
      fi     
    done

    # Let's remove acedb databases too
    if ssh -t ${NODE} "rm -rf ${ACEDB_DIRECTORY}/wormbase_WS${i}"
    then
       echo "Successfully purged ${ACEDB_DIRECTORY}/wormbase_WS${i} from ${NODE}"
    fi     
  done
  echo "==========================================="
done
