#!/bin/bash

# This simple script pushes new software onto production nodes.
# It is intended to be run on the machine hosting the staging
# directory.  You'll need to have SSH set up appropriately 
# (keys and config)

export RSYNC_RSH=ssh
DO_RESTART=$1

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


# Original: not necessary to pass through brie3
alert "Pushing software onto ${STAGING_NODE}"
if rsync -Cav --exclude extlib \
              --exclude gbrowse \
              --exclude gbrowse/ \
              --exclude localdefs.pm \
              --exclude httpd.conf \
              --exclude perl.startup \
              --exclude cache/ \
              --exclude session/ \
              --exclude databases/ \
              --exclude tmp/ \
              --exclude ace_images/ \
              --exclude mt/ \
              ${SITE_STAGING_DIRECTORY}/ ${STAGING_NODE}:${SITE_TARGET_DIRECTORY}
  then
    success "Successfully pushed software onto ${STAGING_NODE}..."
  else
    failure "Pushing software onto ${STAGING_NODE} failed..."
    exit
fi


alert "Pushing software onto nodes..."
for NODE in ${SITE_NODES}
do
  alert " Updating ${NODE}..."
  if ssh ${STAGING_NODE} "rsync -Cav --exclude gbrowse --exclude gbrowse/ --exclude extlib/ --exclude perl.startup --exclude localdefs.pm --exclude httpd.conf --exclude cache/ --exclude session/ --exclude databases/ --exclude mt/ --exclude tmp/ --exclude ace_images/ ${SITE_TARGET_DIRECTORY}/ ${NODE}:${SITE_TARGET_DIRECTORY}"
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
