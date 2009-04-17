#!/bin/bash

# Purge old releases from backend machines

VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

ACEDB_DIRECTORY=/usr/local/acedb
MYSQL_DATA_DIRECTORY=/usr/local/mysql/data
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
      if ssh ${NODE} "rm -rf /usr/local/mysql/data/${DATABASE}_WS${i}"
	  then
	  echo " Successfully deleted ${DATABASE_WS${i} from ${NODE}..."
      fi     
    done

    # Let's remove acedb databases too
    if ssh -t ${NODE} "rm -rf /usr/local/acedb/elegans_WS${i}"
    then
       echo "Successfully purged /usr/local/acedb/elegans_WS${i} from ${NODE}"
    fi     
  done
  echo "==========================================="
done
