#/bin/bash

# GoLive with a new database.
# Adjusts symlinks and restarts services

# Push acedb onto appropriate nodes
export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi


# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

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


function adjust_acedb_symlink() {
    NODE=$1
    alert " Adjusting symlinks on ${NODE}:"
    
    # Set up the symlink
    if ssh ${NODE} "cd ${ACEDB_ROOT}; rm wormbase;  ln -s ${ACEDB_DIR} wormbase"
    then
	success "Successfully symlinked wormbase -> ${ACEDB_DIR}"
    else
	failure "Symlinking failed"
    fi
}


exit

function adjust_mysql_symlinks() {
    NODE=$1
    alert " Adjusting mysql symlinks on ${NODE}:"

    for SPECIES in ${MYSQL_DATABASES} 
    do    
    # Has this species been updated during this release?
	# This doesn't work if wb-dev has already been updated to the next release.
	this_link=`readlink ${SPECIES}`
	this_version=`expr match "${this_link}" '.*_\(WS...\)'`
	echo "Checking if ${SPECIES} was updated during the release cycle of ${VERSION}..."
	
    # Was this species updated during this release?
	if [ ${this_version} = ${VERSION} ]
	then
	    
	    TARGET=${SPECIES}_${VERSION}
	    echo "Adjusting mysql symlinks for ${SPECIES}_${VERSION} on ${NODE}..."
         # Update symlinks
	    if ssh ${NODE} "cd ${TARGET_MYSQL_DATA_DIR}; rm ${SPECIES};  ln -s ${TARGET} ${SPECIES}"
	    then
		success "Successfully symlinked ${SPECIES} -> ${TARGET}"
	    else
		failure "Symlinking failed"
	    fi
	fi
    done
}


# OICR NODES
for NODE in ${OICR_ACEDB_NODES}
do
    adjust_acedb_symlink $NODE
done

for NODE in ${OICR_MYSQL_NODES}
do
    adjust_mysql_symlinks $NODE
done


# Deal with remote nodes
for NODE in ${REMOTE_ACEDB_NODES}
do
    adjust_acedb_symlink $NODE
done

# Deal with remote nodes
for NODE in ${REMOTE_MYSQL_NODES}
do
    adjust_mysql_symlinks $NODE
done
