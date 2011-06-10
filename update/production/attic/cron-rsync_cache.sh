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

# Rsync precache into staging
function rsync_cache() {
    NODE=$1

      if [ "${NODE}" == "wb-mining.oicr.on.ca" ]
      then
  	  if rsync -Cav --exclude *bak* --exclude web_data/ \
	      ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
 	  then
      		success "Successfully pushed support databases onto ${NODE}"
  	  fi
      else
	  if rsync -Cav --exclude *bak* \
              --exclude web_data/ \
	      --exclude blast \
	      --exclude blat \
	      ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
#	      --delete ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
  	  then
      	      success "Successfully pushed support databases onto ${NODE}"
  	  fi
      fi
}


######################################################
#
#    OICR 
#
######################################################
alert "Pushing software onto OICR nodes..."
for NODE in ${OICR_SITE_NODES}
do
    rsync_cache $NODE
done



######################################################
#
#    REMOTE SITE NODES
#
######################################################
alert "Pushing software onto remote nodes..."
for NODE in ${REMOTE_SITE_NODES}
do
   rsync_cache $NODE
done


exit
