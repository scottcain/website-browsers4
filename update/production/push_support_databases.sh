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


alert "Pushing the support databases directory to the staging production node ${NFS_NODE}"
#if rsync --progress -Ca --exclude *bak* \
#  	 --exclude blast \
#	 --exclude blat \
#		${SUPPORT_DB_DIRECTORY}/${VERSION} ${STAGING_NODE}:${SUPPORT_DB_DIRECTORY}
#then
#       success "Successfully pushed support databases onto ${NODE}"
#fi

cd ${SUPPORT_DB_DIRECTORY}
tar czf ${VERSION}.tgz ${VERSION}
if rsync --progress -Cav ${VERSION}.tgz ${NFS_NODE}:${NFS_ROOT}/databases
then
    success "Successfully push support databases onto ${NFS_NODE}"
else
    failure "Could't push support databases onto ${NFS_NODE}"
fi

# Unpack on the staging node
if ssh ${NFS_NODE} "cd ${NFS_ROOT}/databases; tar xzf ${VERSION}.tgz"
then 
    success "Succesfully unpacked the support databases dir on ${NFS_NODE}"
    ssh ${NFS_NODE} "cd ${NFS_ROOT}/databases; rm -rf ${VERSION}.tgz"
else
    failure "Couldn't unpack on the ${NFS_NODE}"
fi

exit


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
      # Nobody else needs blast/blat
      if ssh ${STAGING_NODE} rsync --progress -Ca --exclude *bak* \
	  --exclude blast/ \
	  --exclude blat/ \
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

