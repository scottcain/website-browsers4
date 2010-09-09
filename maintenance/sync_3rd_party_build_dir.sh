#!/bin/bash

# Sync the 3rd party build directory to production nodes

# Pull in shared variables
source ../update/production/update.conf

USER=todd
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



alert "Syncing the 3rd party build directory to the nfs node: ${NFS_NODE}...";
rsync -Ca ${THIRD_PARTY_BUILD_HOME}/${THIRD_PARTY_BUILD_DIR} ${USER}@${NFS_NODE}:${NFS_ROOT}

exit


# No longer required
for NODE in ${SITE_NODES}
do
  alert "  Syncing from the staging node to internal node ${NODE}..."

    if ssh ${STAGING_NODE} "rsync -Ca ${THIRD_PARTY_BUILD_HOME}/${THIRD_PARTY_BUILD_DIR} ${NODE}:${THIRD_PARTY_BUILD_HOME}"

    then
      success "Successfully rsynced 3rd party build dir onto ${NODE}"
    else
	failure "Rsyncing 3rd party build dir onto ${NODE} failed"
    fi
done