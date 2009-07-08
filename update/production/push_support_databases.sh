#!/bin/bash

# Sync support databases out to production nodes

# Pull in my configuration variables shared across scripts
source update.conf

export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

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


alert "Pushing the support databases directory to the staging production node ${STAGING_NODE}"
if rsync --progress -Ca --exclude *bak* \
  	 --exclude blast \
	 --exclude blat \
		${SUPPORT_DB_DIRECTORY}/${VERSION} ${STAGING_NODE}:${SUPPORT_DB_DIRECTORY}
then
       success "Successfully pushed support databases onto ${NODE}"
fi






for NODE in ${SUPPORT_DB_NODES}
do
  alert " ${NODE}:"
  if [ "${NODE}" == "blast.wormbase.org" ]
  then
  	if ssh ${STAGING_NODE} rsync --progress -Cavv --exclude *bak* \
	 	${SUPPORT_DB_DIRECTORY}/${VERSION} ${NODE}:${SUPPORT_DB_DIRECTORY}
 	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   else
	if ssh ${STAGING_NODE} rsync --progress -Ca --exclude *bak* \
		--exclude blast \
		--exclude blat \
		${SUPPORT_DB_DIRECTORY}/${VERSION} ${NODE}:${SUPPORT_DB_DIRECTORY}
  	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   fi
done

exit



# Original: if we do not need to pass through brie3
# Sync the currnet database directory to the support hosts
alert "Pushing the support databases dir on database nodes..."
for NODE in ${SUPPORT_DB_NODES}
do
  alert " ${NODE}:"
  if [ "${NODE}" == "blast.wormbase.org" ]
  then
  	if rsync --progress -Cavv --exclude *bak* \
	 	${SUPPORT_DB_DIRECTORY}/${VERSION} ${NODE}:${SUPPORT_DB_DIRECTORY}
 	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   else
	if rsync --progress -Ca --exclude *bak* \
		--exclude blast \
		--exclude blat \
		${SUPPORT_DB_DIRECTORY}/${VERSION} ${NODE}:${SUPPORT_DB_DIRECTORY}
  	then
      		success "Successfully pushed support databases onto ${NODE}"
  	fi
   fi

done

exit;

