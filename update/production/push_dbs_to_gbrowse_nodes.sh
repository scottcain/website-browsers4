#!/bin/bash

#################################################
# Rsync MySQL databases to the production nodes
#################################################

# Pull in my configuration variables shared across scripts
source update.conf

UPDATED_SPECIES=();
UPDATED_DBS=();
VERSION=$1

export RSYNC_RSH=ssh

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
	for NODE in ${GBROWSE_PRODUCTION_NODES}
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
