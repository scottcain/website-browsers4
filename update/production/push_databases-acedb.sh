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

alert "Pushing Acedb onto staging node..."
if rsync -Ca ${ACEDB_DIR} ${STAGING_NODE}:${ACEDB_ROOT}
then
  success "Successfully pushed acedb onto ${STAGING_NODE}"

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

alert "Pushing Acedb onto production nodes..."
for NODE in ${ACEDB_NODES}
do
  alert " ${NODE}:"
  if ssh ${STAGING_NODE} "rsync -Ca ${ACEDB_DIR} ${NODE}:${ACEDB_ROOT}"
  then
    success "Successfully pushed acedb onto ${NODE}"

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

  else
    failure "Pushing acedb onto ${NODE} failed"
  fi
done

exit





# Original: when not necessary to pass through intermediate staging server
for NODE in ${ACEDB_NODES}
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
