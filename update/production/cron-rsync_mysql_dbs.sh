#!/bin/bash

# Keep mysql databases in sync.
# This only needs to run once a day, starting on 
# say, the 10th of the month.
# Symlinks are updated when we go live.

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

export RSYNC_RSH=ssh

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
    
    for SPECIES in ${MYSQL_DATABASES} 
    do	
	cd ${STAGING_MYSQL_DATA_DIR}
	sudo chmod 2775 ${SPECIES}_WS*

        if rsync -Cav --include "${SPECIES}_WS*" --exclude "/*" ${STAGING_MYSQL_DATA_DIR}/ ${NODE}:${TARGET_MYSQL_DATA_DIR}/
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


################################### 
# Push onto the OICR_NODES.
alert "Rsyncing mysql DBs onto local production nodes..."
for NODE in ${OICR_MYSQL_NODES}
do
    do_rsync $NODE
done

alert "Rsyncing mysql DBs onto remote production nodes..."
for NODE in ${REMOTE_MYSQL_NODES}
do
    do_rsync $NODE
done

exit




#rsync -Cav /usr/local/wormbase/website-classic-staging/html/images/expression/ \
#    gb1:/usr/local/wormbase/gbrowse-support-files/images


# Configuration files:


