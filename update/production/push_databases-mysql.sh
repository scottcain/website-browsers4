#!/bin/bash

# Rsync mysql databases to my primary staging directory at CSHL.
# From there, rsync them to each production node

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

echo ${MYSQL}

alert "Pushing databases to the production staging server ${STAGING_NODE}..."
# First, we mirror to (one) of the production nodes at CSHL.
for DB in ${MYSQL_DATABASES} 
do
    TARGET=${DB}_${VERSION}
    if rsync -Cav --exclude *bak* ${STAGING_MYSQL_DATA_DIR}/${TARGET} ${STAGING_NODE}:${TARGET_MYSQL_DATA_DIR}
    then
      success "Successfully pushed ${DB} onto ${STAGING_NODE}"
      
      # Set up appropriate symlinks and permissions
      if ssh ${STAGING_NODE} "cd ${TARGET_MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}"
      then
	  success "Successfully symlinked ${DB} -> ${TARGET}"
      else
	  failure "Symlinking failed"
      fi

      # Fix permissions
#      if ssh ${STAGING_NODE} "cd ${LOCAL_MYSQL_DATA_DIR}; chown -R todd:mysql ${TARGET}"
      if ssh ${STAGING_NODE} "cd ${TARGET_MYSQL_DATA_DIR}; chmod 664 ${TARGET}/*"
      then
	  success "Successfully fixed permissions on ${TARGET}"
      else
	  failure "Fixing permissions on ${TARGET} failed"
      fi

    else
	failure "Pushing ${DB} onto ${STAGING_NODE} failed"
    fi
done


# Now push from the original production nodes out to the others
alert "Pushing mysql databases onto mysql nodes..."
for NODE in ${MYSQL_NODES}
do
  alert " ${NODE}:"

  for DB in ${MYSQL_DATABASES} 
  do
    TARGET=${DB}_${VERSION}
    if ssh ${STAGING_NODE} "rsync -Cav --exclude *bak* ${TARGET_MYSQL_DATA_DIR}/${TARGET} ${NODE}:${TARGET_MYSQL_DATA_DIR}"
    then
      success "Successfully pushed ${DB} onto ${NODE}"
      
      # Set up appropriate symlinks and permissions
      if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}'"
      then
	  success "Successfully symlinked ${DB} -> ${TARGET}"
      else
	  failure "Symlinking failed"
      fi

      # Fix permissions
      if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; chown -R todd:mysql ${TARGET}'"
      then
	  success "Successfully fixed permissions on ${TARGET}"
      else
	  failure "Fixing permissions on ${TARGET} failed"
      fi

    else
	failure "Pushing ${DB} onto ${NODE} failed"
    fi
  done
done


exit



# Original structure not passing through brie3
alert "Pushing mysql databases onto mysql nodes..."
for NODE in ${MYSQL_NODES}
do
  alert " ${NODE}:"

  for DB in ${MYSQL_DATABASES} 
  do
    TARGET=${DB}_${VERSION}
    if rsync -Ca --exclude *bak* ${STAGING_MYSQL_DATA_DIR}/${TARGET} ${NODE}:${TARGET_MYSQL_DATA_DIR}
    then
      success "Successfully pushed ${DB} onto ${NODE}"
      
      # Set up appropriate symlinks and permissions
      if ssh ${NODE} "cd ${TARGET_MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}"
      then
	  success "Successfully symlinked ${DB} -> ${TARGET}"
      else
	  failure "Symlinking failed"
      fi

      # Fix permissions
      if ssh ${NODE} "cd ${TARGET_MYSQL_DATA_DIR}; chown -R todd:mysql ${TARGET}"
      then
	  success "Successfully fixed permissions on ${TARGET}"
      else
	  failure "Fixing permissions on ${TARGET} failed"
      fi

    else
	failure "Pushing ${DB} onto ${NODE} failed"
    fi
  done
#for DB in ${MYSQL_OLD_DATABASES} 
#    TARGET=${DB}_${VERSION}
#      # Old style symlinks. Deprecated with WS192
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}"
#      then
#	  success "Successfully symlinked ${DB} -> ${TARGET}"
#      else
#	  failure "Symlinking failed"
#      fi
#done


# Other static databases. Not necessary - just a convenience to ensure they are in place
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/c_japonica_3 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed c_japonica onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm c_japonica;  ln -s c_japonica_3 c_japonica"
#      then
#	  success "Successfully symlinked c_japonica -> c_japonica_3"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql c_japonica_3"
#      then
#	  success "Successfully fixed permissions on c_japonica_3"
#      else
#	  failure "Fixing permissions on c_japonica_3 failed"
#      fi
#fi

done

exit



# None of this is necessary any longer
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/c_brenneri_4 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed c_brenneri onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm c_brenneri;  ln -s c_brenneri_4 c_brenneri"
#      then
#	  success "Successfully symlinked c_brenneri -> c_brenneri_4"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql c_brenneri_4"
#      then
#	  success "Successfully fixed permissions on c_brenneri_4"
#      else
#	  failure "Fixing permissions on c_brenneri_4 failed"
#      fi
#fi
#
#
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/b_malayi_bma1 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed b_malayi onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm b_malayi;  ln -s b_malayi_bma1 b_malayi"
#      then
#	  success "Successfully symlinked b_malayi -> b_malayi_bma1"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql b_malayi_bma1"
#      then
#	  success "Successfully fixed permissions on b_malayi_bma1"
#      else
#	  failure "Fixing permissions on b_malayi_bma1 failed"
#      fi
#fi
#
#
#done






