#!/bin/bash

# Pull the software staging directory onto a node (or virtual machine)
# T. Harris (harris@cshl.edu)
# 02 Oct 2007

STAGING_HOST=rsync://dev.wormbase.org
RSYNC_MODULE=wormbase-live/
TARGET_DIRECTORY=/usr/local/wormbase

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


alert "Pulling software onto node..."
if rsync -Ca --exclude databases --exclude mt ${STAGING_HOST}/${RSYNC_MODULE} ${TARGET_DIRECTORY}
then
  success "Successfully pulled software onto node..."
else
  failure "Pulling software onto node failed..."
  exit
fi



