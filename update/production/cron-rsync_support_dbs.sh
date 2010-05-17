#!/bin/bash
# filename: cron-rsync_support_dbs.sh

# Sync support databases to production nodes
# To reduce administrative overhead, this script
# is intended to be run as a cron job.

# Pull in my configuration variables shared across scripts
source update.conf

export RSYNC_RSH=ssh
#VERSION=$1
#
#if [ ! "$VERSION" ]
#then
#  echo "Usage: $0 WSXXX"
#  exit
#fi

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


alert "Pushing the support databases dir on database nodes..."
for NODE in ${OICR_SUPPORT_DB_NODES}
do
  alert " ${NODE}:"
  if [ "${NODE}" == "wb-mining.oicr.on.ca" ]
  then
  	if rsync -Cav --exclude *bak* --exclude web_data \
	 	--delete ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
 	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   else
	if rsync -Cav --exclude *bak* \
                --exclude web_data \
	        --exclude blast \
		--exclude blat \
		--delete ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
  	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   fi

done

exit;

