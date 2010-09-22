#!/bin/bash

# Keep mysql databases in sync.
# This only needs to run once a day, starting on 
# say, the 10th of the month.
# Symlinks are updated when we go live.

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

export RSYNC_RSH=ssh
VERSION=$1

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


UPDATED_SPECIES=();
UPDATED_DBS=();


function extract_version() {
    this_species=$1
    this_link=`readlink ${this_species}`
    this_version=`expr match "${this_link}" '.*_\(WS...\)'`
    
    # Save this database if we have been updated
    if [ ${this_version} = ${VERSION} ]
    then
	echo "   ---> ${this_species} UPDATED. New version is ${this_version}"
	UPDATED_SPECIES[${#UPDATED_SPECIES[*]}]=${this_species}
	UPDATED_DBS[${#UPDATED_DBS[*]}]=${this_link}
    else
	echo "   ${this_species} not updated. Current version is ${this_version}"
    fi
}



function do_rsync() {
    NODE=$1
    
    for SPECIES in ${MYSQL_DATABASES} 
    do	
	alert "Rsyncing ${SPECIES} onto ${NODE}..."

	cd ${STAGING_MYSQL_DATA_DIR}
	sudo chmod 2775 ${SPECIES}_WS*

	# I want to run this as a cron job. I won't know the current version.
	# Let's guesstimate some database names that Norie creates that we don't want.
	# Would also be good to purge from local host so we don't re-sync things.
        if rsync -Cav --include "${SPECIES}_WS*" --exclude "bak" --exclude "old" --exclude "/*" ${STAGING_MYSQL_DATA_DIR}/ ${NODE}:${TARGET_MYSQL_DATA_DIR}/
        then
     	    success "Successfully rsynced ${SPECIES} onto ${NODE}"
	    
         # Fix permissions
	    if ssh ${NODE} "cd ${TARGET_MYSQL_DATA_DIR}; chgrp -R mysql ${SPECIES}_*"
	    then
		success "Successfully fixed permissions on ${NODE}:${SPECIES}"
#	    else
#		failure "Fixing permissions on ${NODE}:${SPECIES} failed"
	    fi
	else
	    failure "Rsyncing ${SPECIES} onto ${NODE} failed..."
	fi
    done
}


function do_rsync_updated_dbs() {
    NODE=$1

    for SPECIES in ${UPDATED_SPECIES[*]}
    do
	TARGET=${SPECIES}_${VERSION}
	
	alert "Rsyncing ${SPECIES} onto ${NODE}..."

	cd ${STAGING_MYSQL_DATA_DIR}
	sudo chmod 2775 ${TARGET}

        if rsync -Cav ${STAGING_MYSQL_DATA_DIR}/${TARGET} ${NODE}:${TARGET_MYSQL_DATA_DIR}/
        then
     	    success "Successfully rsynced ${TARGET} onto ${NODE}"
	    
         # Fix permissions
	    if ssh ${NODE} "cd ${TARGET_MYSQL_DATA_DIR}; chgrp -R mysql ${TARGET}"
	    then
		success "Successfully fixed permissions on ${NODE}:${TARGET}"
#	    else
#		failure "Fixing permissions on ${NODE}:${SPECIES} failed"
	    fi
	else
	    failure "Rsyncing ${TARGET} onto ${NODE} failed..."
	fi
    done
}



################################### 
# Get a list of all databases
# ignoring (for now) those that haven't been updated
alert "checking for updated databases"
cd ${STAGING_MYSQL_DATA_DIR}
for DB in ${MYSQL_DATABASES} 
do
    extract_version ${DB}    
done

#exit


################################### 
# Push onto the OICR_NODES.
alert "Rsyncing mysql DBs onto local production nodes..."
for NODE in ${OICR_MYSQL_NODES}
do
#    do_rsync $NODE
    do_rsync_updated_dbs $NODE
done

alert "Rsyncing mysql DBs onto remote production nodes..."
for NODE in ${REMOTE_MYSQL_NODES}
do
#    do_rsync $NODE
    do_rsync_updated_dbs $NODE
done

exit




#rsync -Cav /usr/local/wormbase/website-classic-staging/html/images/expression/ \
#    gb1:/usr/local/wormbase/gbrowse-support-files/images


