#/bin/bash

# Push acedb onto appropriate nodes
export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

# These nodes host the Acedb database
#ACEDB_NODES=`cat conf/nodes_acedb.conf`
ACEDB_NODES=("be1.wormbase.org brie6.cshl.edu aceserver.cshl.org")
#ACEDB_NODES=("brie6 aceserver")
#ACEDB_NODES=("aceserver")
ACEDB_ROOT=/usr/local/acedb
ACEDB_DIR=/usr/local/acedb/elegans_${VERSION}

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

alert "Pushing Acedb onto acedb nodes..."

for NODE in ${ACEDB_NODES}
do
  alert " ${NODE}:"
  if rsync -Ca ${ACEDB_DIR} ${NODE}:${ACEDB_ROOT}
  then
    success "Successfully pushed acedb onto ${NODE}"

    # Set up the symlink
    if ssh ${NODE} "cd ${ACEDB_ROOT}; rm elegans;  ln -s ${ACEDB_DIR} elegans"
    then
	  success "Successfully symlinked elegans -> ${ACEDB_DIR}"
    else
	  failure "Symlinking failed"
    fi

    # Fix permissions
    if ssh ${NODE} "cd ${ACEDB_DIR}; chgrp -R acedb * ; cd database ; chmod 666 block* log.wrm serverlog.wrm ; rm -rf readlocks"
    then
	  success "Successfully fixed permissions on ${ACEDB_DIR}"
    else
	  failure "Fixing permissions on ${ACEDB_DIR} failed"
    fi

  else
    failure "Pushing acedb onto ${NODE} failed"
  fi
done
