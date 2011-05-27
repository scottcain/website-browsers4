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


alert "Pushing the support databases directory to the nfs node ${NFS_NODE}"
#if rsync --progress -Ca --exclude *bak* \
#  	 --exclude blast \
#	 --exclude blat \
#		${SUPPORT_DB_DIRECTORY}/${VERSION} ${STAGING_NODE}:${SUPPORT_DB_DIRECTORY}
#then
#       success "Successfully pushed support databases onto ${NODE}"
#fi


# Package up the full database diretory for the current version
cd ${SUPPORT_DB_DIRECTORY}
tar czf ${VERSION}.tgz ${VERSION}

if rsync --progress -Cav ${VERSION}.tgz ${NFS_NODE}:${NFS_ROOT}/databases
then
    success "Successfully pushed support databases onto nfs node ${NFS_NODE}"
else
    failure "Could't push support databases onto the nfs node ${NFS_NODE}"
fi

# Unpack on the staging node
if ssh ${NFS_NODE} "cd ${NFS_ROOT}/databases; tar xzf ${VERSION}.tgz"
then 
    success "Succesfully unpacked the support databases dir on ${NFS_NODE}"
    
    
    # Hack. Need to push out to canopus
    if ssh ${NFS_NODE} "rsync -Cav ${NFS_ROOT}/databases/${VERSION}.tgz tharris@canopus.caltech.edu:/usr/local/wormbase/databases"
    then
	
        # Unpack on canopus	
	if ssh ${NFS_NODE} "ssh tharris@canopus.caltech.edu 'cd /usr/local/wormbase/databases; tar xzf ${VERSION}.tgz'"
	then 
	    success "Succesfully unpacked the support databases dir on canopus"
	    ssh ${NFS_NODE} "ssh tharris@canopus.caltech.edu 'cd /usr/local/wormbase/databases; rm -rf ${VERSION}.tgz'"
	else
	    failure "Coulddn't unpack the databases tarball on canopus..."
	fi
    fi
    
    # Delete the tarball on the staging node
    ssh ${NFS_NODE} "cd ${NFS_ROOT}/databases; rm -rf ${VERSION}.tgz"
else
    failure "Couldn't unpack on the ${NFS_NODE}"
fi




cd ${SUPPORT_DB_DIRECTORY}
rm ${VERSION}.tgz

exit
