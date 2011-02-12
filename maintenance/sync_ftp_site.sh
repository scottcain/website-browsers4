#!/bin/bash

# Sync the 3rd party build directory to production nodes

# Pull in shared variables
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf

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



alert "Syncing the FTP site to the FTP server: ${FTP_SERVER}...";
if rsync -Cav --rsh=ssh /usr/local/ftp/pub/wormbase ${FTP_SITE_USER}@${FTP_SERVER}:/var/ftp/pub
then
    success "Successfully rsynced staging FTP site onto ${FTP_SERVER}"
else
    failure "Rsyncing ftp staging site onto ${FTP_SERVER} failed"
fi
