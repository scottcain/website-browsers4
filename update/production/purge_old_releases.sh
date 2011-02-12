#!/bin/bash

# Purge old releases from backend machines

VERSION=$1
DO_LOCAL_NODES=$2

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX [BOOLEAN: Only purge from localhost]"
  exit
fi

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf

export RSYNC_RSH=ssh

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

#BASE=`expr "${VERSION}" : 'WS\(...\)'`

# Just purge databases from the local nodes.
# This is by design distinct from other nodes
# since I may need to be root.
if [ $DO_LOCAL_NODES ]
then
    # Acedb
    rm -rf ${ACEDB_ROOT}/wormbase_${VERSION}
    
    # MySQL DBs
    for SPECIES in ${MYSQL_DATABASES}
    do
	rm -rf ${TARGET_MYSQL_DATA_DIR}/${SPECIES}_${VERSION}
    done    

    # Support DBs
    rm -rf ${SUPPORT_DB_DIRECTORY}/${VERSION}
    exit
fi 



function purge_mysql_dbs() {
    NODE=$1
    alert "Purging mysql databases from ${NODE}..."

    for SPECIES in ${MYSQL_DATABASES}
    do
	if ssh ${NODE} "rm -rf ${TARGET_MYSQL_DATA_DIR}/${SPECIES}_${VERSION}"
	then
	    success "Successfully deleted ${SPECIES}_${VERSION} from ${NODE}"
	fi     
    done    
}

function purge_acedb_dbs() {
    NODE=$1
    alert "Purging acedb databases from ${NODE}..."    
    
    if ssh -t ${NODE} "rm -rf ${ACEDB_ROOT}/wormbase_${VERSION}"
    then
	success "Successfully purged ${ACEDB_ROOT}/wormbase_${VERSION} from ${NODE}"
    fi
}

function purge_support_dbs() {
    NODE=$1
    alert "Purging support databases from ${NODE}..."    
    if ssh -t ${NODE} "rm -rf ${SUPPORT_DB_DIRECTORY}/${VERSION}"
    then
	success "Successfully purged ${SUPPORT_DB_DIRECTORY}/${VERSION} from ${NODE}"
    fi
}


# Purge acedb databases from local and remote hosts
ACEDB_NODES=( ${OICR_ACEDB_NODES[@]} ${REMOTE_ACEDB_NODES[@]} )
for NODE in ${ACEDB_NODES[@]}
do
    purge_acedb_dbs $NODE
done

# Purge mysql databases from local and remote hosts
MYSQL_NODES=( ${OICR_MYSQL_NODES[@]} ${REMOTE_MYSQL_NODES[@]} )
for NODE in ${MYSQL_NODES[@]}
do
    purge_mysql_dbs $NODE
done

# Purge support databases
# Using a local NFS Server
SUPPORT_NODES=( ${LOCAL_NFS_SERVER} ${REMOTE_SUPPORT_DB_NODES[@]} )
# ... or when each node hosts all databases
#SUPPORT_NODES=( ${LOCAL_SUPPORT_DB_NODES[@]} ${REMOTE_SUPPORT_DB_NODES[@]} )
for NODE in ${SUPPORT_NODES[@]}
do
    purge_support_dbs $NODE
done


