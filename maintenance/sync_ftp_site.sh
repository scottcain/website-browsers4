#!/bin/bash

# Sync the 3rd party build directory to production nodes

# Pull in shared variables
source /home/tharris/projects/wormbase/admin/update/production/update.conf

USER=todd
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



alert "Syncing the FTP site to the staging node: ${STAGING_NODE}...";
rsync -Cav /usr/local/ftp/pub/wormbase ${USER}@${STAGING_NODE}:/usr/local/ftp/pub/

alert "  Syncing from the staging node to the FTP site..."

if ssh ${STAGING_NODE} "rsync -Cav /usr/local/ftp/pub/wormbase ${FTP_SERVER}:/var/ftp/pub"
    then
      success "Successfully rsynced staging FTP site onto ${FTP_SERVER}"

      # Clear out the staging node
      if ssh ${STAGING_NODE} "rm -rf /usr/local/ftp/pub/wormbase/*"
	  then
	  success "purged the staging node ${STAGING_NODE}"
      else
	  failure "Could not purge the staging node ${STAGING_NODE}..."
      fi
    else
	failure "Rsyncing ftp staging site onto ${FTP_SERVER} failed"
    fi
done
