#/bin/bash

# Push acedb onto appropriate nodes
export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi


# Pull in my configuration variables shared across scripts
source update.conf

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



SYNC_TO_STAGING_NODE=1

if [ $SYNC_TO_STAGING_NODE ]
then
    
# Package up acedb before mirroring
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
	    success "Successfully symlinked elegans -> ${ACEDB_DIR}"
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
	    success "Successfully symlinked elegans -> ${ACEDB_DIR}"
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





# Push onto the OICR_NODES.
# Used when its not necessary to pass through a preliminary staging server
for NODE in ${OICR_ACEDB_NODES}
do
  alert " ${NODE}:"
  if rsync -Ca ${ACEDB_DIR} ${NODE}:${ACEDB_ROOT}
  then
    success "Successfully pushed acedb onto ${NODE}"

    # Set up the symlink
    if ssh ${NODE} "cd ${ACEDB_ROOT}; rm elegans;  ln -s ${ACEDB_DIR} elegans"
    then
	  success "Successfully symlinked elegans -> ${ACEDB_DIR}"
    else
	  failure "Symlinking failed"
    fi

    # Fix permissions
    if ssh ${NODE} "cd ${ACEDB_DIR}; chgrp -R acedb * ; cd database ; chmod 666 block* log.wrm serverlog.wrm ; rm -rf readlocks"
    then
	  success "Successfully fixed permissions on ${ACEDB_DIR}"
    else
	  failure "Fixing permissions on ${ACEDB_DIR} failed"
    fi

  else
    failure "Pushing acedb onto ${NODE} failed"
  fi
done
