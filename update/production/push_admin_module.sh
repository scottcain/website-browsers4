#!/bin/bash

# This simple script pushes new software onto production nodes.
# It is intended to be run on the machine hosting the staging
# directory.  You'll need to have SSH set up appropriately 
# (keys and config)

export RSYNC_RSH=ssh
DO_RESTART=$1

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf


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


cd /home/tharris/projects/wormbase/website-admin
alert "Pushing admin module onto ${STAGING_NODE}"
if rsync -Cav /home/tharris/projects/wormbase/website-admin/ ${LOCAL_NFS_SERVER}:${LOCAL_NFS_ROOT}/admin    
then
    success "Successfully pushed software onto ${LOCAL_NFS_SERVER}..."
else
    failure "Pushing software onto ${STAGING_NODE} failed..."
    exit
fi