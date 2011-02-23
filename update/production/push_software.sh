#!/bin/bash

# This simple script pushes new software onto production nodes.
# It is intended to be run on the machine hosting the staging
# directory.  You'll need to have SSH set up appropriately 
# (keys and config)

export RSYNC_RSH=ssh
DO_RESTART=$1

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf


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


# Original: not necessary to pass through brie3
TEST=
if [ $TEST ]
then
    alert "Pushing software onto ${STAGING_NODE}"
    if rsync -Cav --exclude extlib \
        --exclude cache/ \
        --exclude session/ \
        --exclude databases/ \
        --exclude tmp/ \
        --exclude ace_images/ \
        --exclude html/rss/ \
        ${SITE_STAGING_DIRECTORY}/ ${STAGING_NODE}:${SITE_TARGET_DIRECTORY}
    then
	success "Successfully pushed software onto ${STAGING_NODE}..."
    else
	failure "Pushing software onto ${STAGING_NODE} failed..."
	exit
    fi
fi


if [ $TEST ]
then
    alert "Pushing software onto nodes..."
    for NODE in ${REMOTE_SITE_NODES}
    do
	alert " Updating ${NODE}..."
	if rsync -Cav --exclude extlib/ --exclude cache/ --exclude session/ --exclude databases/ --exclude tmp/ --exclude ace_images/ --exclude html/rss/ ${SITE_TARGET_DIRECTORY}/ ${NODE}:${SITE_TARGET_DIRECTORY}
	then
	    success "Successfully pushed software onto ${NODE}..."
	else
	    failure "Pushing software onto ${NODE} failed..."
#    exit
	fi
    done
fi

# Rsync precache into staging
rsync -Cav ${SITE_TARGET_DIRECTORY}/html/cache/ ${SITE_STAGING_DIRECTORY}/html/cache



function rsync_software() {
   NODE=$1
  alert " Updating ${NODE}..."
  if rsync -Cav --exclude extlib \
                --exclude cache/ \
                --exclude session/ \
                --exclude databases/ \
                --exclude tmp/ \
                --exclude ace_images/ \
                --exclude html/rss/ \
              ${SITE_STAGING_DIRECTORY}/ ${NODE}:${SITE_TARGET_DIRECTORY}
  then
    success "Successfully pushed software onto ${NODE}..."
  else
    failure "Pushing software onto ${NODE} failed..."
  fi
}

function rsync_images() {
    NODE=$1
     rsync -Cav /usr/local/wormbase/website-shared-files $NODE:/usr/local/wormbase/
}

######################################################
#
#    OICR 
#
######################################################
alert "Pushing software onto OICR nodes..."
for NODE in ${OICR_SITE_NODES}
do
    rsync_software $NODE
    rsync_images $NODE
done



######################################################
#
#    REMOTE SITE NODES
#
######################################################
alert "Pushing software onto OICR nodes..."
for NODE in ${REMOTE_SITE_NODES}
do
   rsync_software $NODE
   rsync_images $NODE
done


# Now sync the admin module
#alert "Pushing the admin module onto OICR nodes..."
#for NODE in ${OICR_ALL_NODES}
#do
#  alert " Updating ${NODE}..."
#  if rsync -Cav /home/tharris/projects/wormbase/website-admin/ ${NODE}:/usr/local/wormbase/admin
#  then
#    success "Successfully pushed software onto ${NODE}..."
#  else
#    failure "Pushing software onto ${NODE} failed..."
#  fi
#done

exit

# Is a restart necessary?
if [ "${DO_RESTART}" ]
then
   ./restart_services.sh
fi

exit





# Original: not necessary to pass through brie3
alert "Pushing software onto nodes..."
for NODE in ${SITE_NODES}
do
  alert " Updating ${NODE}..."
  if rsync -Ca --exclude databases --exclude mt ${SITE_STAGING_DIRECTORY} ${NODE}:${SITE_TARGET_DIRECTORY}
  then
    success "Successfully pushed software onto ${NODE}..."
  else
    failure "Pushing software onto ${NODE} failed..."
    exit
  fi
done

# Is a restart necessary?
if [ "${DO_RESTART}" ]
then
   ./restart_services.sh
fi
