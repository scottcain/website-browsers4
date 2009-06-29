#!/bin/bash

# This simple script pushes new software onto production nodes.
# It is intended to be run on the machine hosting the staging
# directory.  You'll need to have SSH set up appropriately 
# (keys and config)

export RSYNC_RSH=ssh
DO_RESTART=$1

STAGING_DIRECTORY=/usr/local/wormbase/website-classic-staging
TARGET_DIRECTORY=/usr/local/wormbase/website-classic
NODES=`cat conf/nodes_all.conf`
#NODES=`cat conf/be_only.conf`
#NODES=gene
#NODES=vab
#NODES=be1

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


alert "Pushing software onto nodes..."
for NODE in ${NODES}
do

  alert " Updating ${NODE}..."
  if rsync -Ca --exclude databases --exclude mt ${STAGING_DIRECTORY} ${NODE}:${TARGET_DIRECTORY}
  then
    success "Successfully pushed software onto ${NODE}..."
  else
    failure "Pushing software onto ${NODE} failed..."
    exit
  fi
done

# Is a restart necessary?
if [ "${DO_RESTART}" ]
then
   ./restart_services.sh
fi
