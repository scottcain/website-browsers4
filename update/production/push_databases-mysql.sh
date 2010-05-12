#!/bin/bash

# Rsync mysql databases to my primary staging directory at CSHL.
# From there, rsync them to each production node

# Pull in my configuration variables shared across scripts
source update.conf

UPDATED_SPECIES=();
UPDATED_DBS=();

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

function extract_version() {
    this_species=$1
    this_link=`readlink ${this_species}`
    this_version=`expr match "${this_link}" '.*_\(WS...\)'`
    echo "CHECKING FOR NEW DATABASES: ${this_species} ${this_version}"

    # Save this if we have been updated
    if [ ${this_version} = ${VERSION} ]
    then
#	echo ${#UPDATED_SPECIES[*]}
	UPDATED_SPECIES[${#UPDATED_SPECIES[*]}]=${this_species}
	UPDATED_DBS[${#UPDATED_DBS[*]}]=${this_link}
    fi
}



################################### 
# Get a list of all databases
# ignoring (for now) those that haven't been updated
cd ${STAGING_MYSQL_DATA_DIR}
for DB in ${MYSQL_DATABASES} 
do
    extract_version ${DB}    
done

#echo ${#UPDATED_SPECIES[*]}
#echo ${#UPDATED_DBS[*]}

    
    

################################
# Copying databases as a tarball

# Sync to the staging node
SYNC_TO_STAGING_NODE=
if [ $SYNC_TO_STAGING_NODE ]
then
    
# Tar up modified databases
# First, concatenate my array of modified databases

    SAVE_IFS=$IFS
    IFS=" "
    MODIFIED_DBS="${UPDATED_DBS[*]}"
    IFS=$SAVE_IFS
    
    echo "Tarring up $MODIFIED_DBS"

    cd ${STAGING_MYSQL_DATA_DIR}
    tar -czf mysql_${VERSION}.tgz *${MODIFIED_DBS}    

    if rsync -Cav mysql_${VERSION}.tgz ${STAGING_NODE}:${TARGET_MYSQL_DATA_DIR}
    then
	success "Successfully pushed mysql tarball onto ${STAGING_NODE}"
	
        # Unpack it
	if ssh ${STAGING_NODE} "cd ${TARGET_MYSQL_DATA_DIR}; tar xzf mysql_${VERSION}.tgz"
	then
	    success "Successfully unpacked the mysql databases..."
	else
	    failure "Coulddn't unpack the mysql tarball on ${STAGING_NODE}..."
	fi
	
	
	for SPECIES in ${UPDATED_SPECIES[*]}
	do
	    TARGET=${SPECIES}_${VERSION}
	    
      # Fix permissions
	    if ssh ${STAGING_NODE} "cd ${TARGET_MYSQL_DATA_DIR}; chgrp -R mysql ${TARGET}"
	    then
		success "Successfully fixed permissions on ${TARGET}"
	    else
		failure "Fixing permissions on ${TARGET} failed"
	    fi
	    
      # Set up appropriate symlinks and permissions for each database
	    if ssh ${STAGING_NODE} "cd ${TARGET_MYSQL_DATA_DIR}; rm ${SPECIES};  ln -s ${TARGET} ${SPECIES}"
	    then
		success "Successfully symlinked ${SPECIES} -> ${TARGET}"
	    else
		failure "Symlinking failed"
	    fi
	done
    fi
fi      


# Now push from the original production nodes out to the others
alert "Pushing mysql databases onto mysql nodes..."
for NODE in ${MYSQL_NODES}
do
    alert " ${NODE}:"
    
    if ssh ${STAGING_NODE} "rsync -Cav ${TARGET_MYSQL_DATA_DIR}/mysql_${VERSION}.tgz ${NODE}:${TARGET_MYSQL_DATA_DIR}"
  then
      success "Successfully pushed mysql tarball onto ${NODE}"
      
  # Unpack it
      if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; tar xzf mysql_${VERSION}.tgz'"
      then
	  success "Successfully unpacked the mysql tarball..."
      else
	  failure "Coulddn't unpack the mysql tarball on ${NODE}..."
      fi
      
      # Now fix the permissions and symlink to each database
      for SPECIES in ${UPDATED_SPECIES[*]} 
      do
	  TARGET=${SPECIES}_${VERSION}
	  
      # Set up appropriate symlinks and permissions
	  if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; rm ${SPECIES};  ln -s ${TARGET} ${SPECIES}'"
	  then
	      success "Successfully symlinked ${SPECIES} -> ${TARGET}"
	  else
	      failure "Symlinking failed"
	  fi
	  
      # Fix permissions
	  if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; chgrp -R mysql ${TARGET}'"
	  then
	      success "Successfully fixed permissions on ${TARGET}"
	  else
	      failure "Fixing permissions on ${TARGET} failed"
	  fi
      done  
      
      # Now remove the tarball
      if ssh ${STAGING_NODE} "ssh ${NODE} 'cd ${TARGET_MYSQL_DATA_DIR}; rm -rf mysql_${VERSION}.tgz'"
      then
	  success "Successfully removed the mysql tarball from ${NODE}"
      else
	  failure "Could not remove the mysql tarball from ${NODE}"
      fi
    else
	failure "Pushing mysql onto ${NODE} failed"
    fi
done


# Remove the local tarball
cd ${STAGING_MYSQL_DATA_DIR}
rm -rf mysql_${VERSION}.tgz

# And the tarball on the staging node
ssh ${STAGING_NODE} "rm -rf ${TARGET_MYSQL_DATA_DIR}/mysql_${VERSION}.tgz"


exit






################################
# Copying databases one by one

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





##############################
# OICR DIRECT RSYNC
function do_rsync() {
    this_species=$1
    cd ${GBROWSE_PRODUCTION_MYSQL_DATA_DIR}
    this_link=`readlink ${this_species}`
    this_version=`expr match "${this_link}" '.*_\(WS...\)'`
    echo "Checking if ${this_species} was updated during the release cycle of ${VERSION}..."
    
    # Was this species updated during this release?
    if [ ${this_version} = ${VERSION} ]
    then

	TARGET=${this_species}_${VERSION}
	
	# Rsync it to every node
	for NODE in ${OICR_MYSQL_NODES}
	do

	    echo "${this_species} was updated. Rsyncing to ${NODE}..."
            if rsync -Cav ${TARGET} ${NODE}:${TARGET_MYSQL_DATA_DIR}
            then
     		success "Successfully pushed ${this_species}_${VERSION} onto ${NODE}"
		
                # Fix permissions
		if ssh ${NODE} "cd ${GBROWSE_PRODUCTION_MYSQL_DATA_DIR}; chgrp -R mysql ${TARGET}"
		then
		    success "Successfully fixed permissions on ${TARGET}"
		else
		    failure "Fixing permissions on ${TARGET} failed"
		fi
	    
                # Set up appropriate symlinks and permissions for each database
		if ssh ${NODE} "cd ${GBROWSE_PRODUCTION_MYSQL_DATA_DIR}; rm ${this_species};  ln -s ${TARGET} ${this_species}"
		then
		    success "Successfully symlinked ${this_species} -> ${TARGET}"
		else
		    failure "Symlinking failed"
		fi
	    fi
	done
    else
	echo "${this_species} was not updated. Skipping..."
    fi
}


################################### 
# Get a list of all databases
# ignoring (for now) those that haven't been updated
for DB in ${MYSQL_DATABASES} 
do
    do_rsync ${DB}    
done



# Expression pattern images:
#rsync -Cav /usr/local/wormbase/website-classic-staging/html/images/expression/ \
#    gb1:/usr/local/wormbase/gbrowse-support-files/images


# Configuration files:


