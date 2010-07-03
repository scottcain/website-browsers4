#/bin/bash

# Keep /usr/local/wormbase/acedb/wormbase* in sync
# This only needs to run once a day, starting on 
# say, the 10th of the month.
# Symlinks are updated when we go live.


export RSYNC_RSH=ssh

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

function do_rsync() {
    NODE=$1
    alert " rsyncing to ${NODE}:"

    # Include only the wormbase_* directories, exclude everything else
    if rsync --rsh=ssh -Cav --include "wormbase_*"  --exclude serverlog.wrm --exclude log.wrm --exclude readlocks --exclude "/*" ${ACEDB_ROOT}/ ${NODE}:${ACEDB_ROOT}/
    then
	success "Successfully rsynced acedb databases onto ${NODE}"

    # Fix permissions
	if ssh ${NODE} "cd ${ACEDB_ROOT}; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks"
	then
	    success "Successfully fixed permissions on ${NODE}:${ACEDB_ROOT}"
	else
	    failure "Fixing permissions on ${NODE}:${ACEDB_ROOT} failed"
	fi

    else
	failure "Pushing acedb onto ${NODE} failed"
    fi
}



# Push onto the OICR_NODES.
# Used when its not necessary to pass through a preliminary staging server
alert "Rsyncing Acedb data directories onto local production nodes..."
for NODE in ${OICR_ACEDB_NODES}
do
    do_rsync $NODE
done


alert "Rsyncing Acedb data directories onto remote production nodes..."
for NODE in ${REMOTE_ACEDB_NODES}
do
    do_rsync $NODE
done


exit



# Here's how to sync via a tarball
SYNC_TO_STAGING_NODE=

if [ $SYNC_TO_STAGING_NODE ]
then
    
# Package up acedb before mirroring to remote sites
    cd ${ACEDB_ROOT}
    
    alert "packaging acedb..."
    tar czf wormbase_${VERSION}.tgz wormbase_${VERSION}
    
    alert "Pushing Acedb onto staging node..."
#if rsync -Cav ${ACEDB_DIR} ${STAGING_NODE}:${ACEDB_ROOT}
    if rsync -Cav wormbase_${VERSION}.tgz ${STAGING_NODE}:${ACEDB_ROOT}
    then
	success "Successfully pushed acedb onto ${STAGING_NODE}"
	
  # Unpack it
	if ssh ${STAGING_NODE} "cd ${ACEDB_ROOT}; tar xzf wormbase_${VERSION}.tgz"
	then
	    success "Successfully unpacked the acedb database..."
	else
	    failure "Coulddn't unpack the acedb on ${STAGING_NODE}..."
	fi
	
   # Set up the symlink
	if ssh ${STAGING_NODE} "cd ${ACEDB_ROOT}; rm wormbase;  ln -s ${ACEDB_DIR} wormbase"
	then
	    success "Successfully symlinked wormbase -> ${ACEDB_DIR}"
	else
	    failure "Symlinking failed"
	fi
	
   # Fix permissions
	if ssh ${STAGING_NODE} "cd ${ACEDB_DIR}; chgrp -R acedb * ; cd database ; chmod 666 block* log.wrm serverlog.wrm ; rm -rf readlocks"
	then
	    success "Successfully fixed permissions on ${ACEDB_DIR}"
	else
	    failure "Fixing permissions on ${ACEDB_DIR} failed"
	fi
	
    else
	failure "Pushing acedb onto ${STAGING_NODE} failed"
    fi



alert "Pushing Acedb onto production nodes..."
for NODE in ${ACEDB_NODES}
do
    
  # Skip the staging node - already copied AceDB to it above.
    if [ ${NODE} = ${STAGING_NODE} ]; then
	next
    fi
    
    alert " ${NODE}:"
    if ssh ${STAGING_NODE} "rsync -Cav ${ACEDB_ROOT}/wormbase_${VERSION}.tgz ${NODE}:${ACEDB_ROOT}"
    then
	success "Successfully pushed acedb onto ${NODE}"
	
  # Unpack it
	if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${ACEDB_ROOT}; tar xzf wormbase_${VERSION}.tgz'"
	then
	    success "Successfully unpacked the acedb database..."
	else
	    failure "Coulddn't unpack the acedb on ${NODE}..."
	fi
	
    # Set up the symlink
	if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${ACEDB_ROOT}; rm wormbase;  ln -s ${ACEDB_DIR} wormbase'"
	then
	    success "Successfully symlinked wormbase -> ${ACEDB_DIR}"
	else
	    failure "Symlinking failed"
	fi
	
    # Fix permissions
	if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${ACEDB_DIR}; chgrp -R acedb * ; cd database ; chmod 666 block* log.wrm serverlog.wrm ; rm -rf readlocks'"
	then
	    success "Successfully fixed permissions on ${ACEDB_DIR}"
	else
	    failure "Fixing permissions on ${ACEDB_DIR} failed"
	fi
	
    # Finally, remove the tarball
	if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${ACEDB_ROOT} ; rm -rf wormbase_${VERSION}.tgz'"
	then
	    success "removed the acedb tarball..."
	else
	    failure "could not remove the acedb tarball..."
	fi
	
    else
	failure "Pushing acedb onto ${NODE} failed"
    fi
done


# Finally, remove the local acedb tarball
rm -rf ${ACEDB_ROOT}/wormbase_${VERSION}.tgz

# And remove it from the staging node, too
ssh ${STAGING_NODE} "rm -rf ${ACEDB_ROOT}/wormbase_${VERSION}.tgz"
fi