#!/bin/bash
# filename: cron-rsync_support_dbs.sh

# Sync support databases to production nodes
# To reduce administrative overhead, this script
# is intended to be run as a cron job.

# Pull in my configuration variables shared across scripts

source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

export RSYNC_RSH=ssh
#VERSION=$1
#
#if [ ! "$VERSION" ]
#then
#  echo "Usage: $0 WSXXX"
#  exit
#fi

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
      alert " ${NODE}:"

      # The data mining node also gets blast and blat databases
      if [ "${NODE}" == "wb-mining.oicr.on.ca" ]
      then
  	  if rsync -Cav --exclude *bak* --exclude web_data/ \
	      ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
 	  then
      		success "Successfully pushed support databases onto ${NODE}"
  	  fi
      else
	  if rsync -Cav --exclude *bak* \
              --exclude web_data/ \
	      --exclude blast \
	      --exclude blat \
	      ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
#	      --delete ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
  	  then
      	      success "Successfully pushed support databases onto ${NODE}"
  	  fi
      fi
}


function rsync_admin_module() {
    NODE=$1
    alert "Rsyncing the admin module to ${NODE}..."
    if rsync -Cav /home/tharris/projects/wormbase/wormbase-admin/ ${NODE}:/usr/local/wormbase/admin
    then
	success "Successfully pushed software onto ${NODE}..."
    else
	failure "Pushing software onto ${NODE} failed..."
    fi
}


function rsync_to_nfs_server() {
    NODE=$1
    alert " Rsyncing to ${NODE}:"
    if rsync -Cav --exclude *bak* --exclude web_data/ \
	 ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${LOCAL_NFS_ROOT}/databases
    then
      	success "Successfully pushed support databases onto ${NODE}"
    fi
}


# 1. The NFS server hosts all our databases
#rsync_to_nfs_server ${LOCAL_NFS_SERVER};

# 2. ALL nodes maintain their own databases
#alert "Rsyncing support databases onto local nodes..."
for NODE in ${OICR_SUPPORT_DB_NODES}
do
     do_rsync $NODE;
#     rsync_admin_module $NODE;
done

alert "Rsyncing support databases onto remote nodes..."
for NODE in ${REMOTE_SUPPORT_DB_NODES}
do
     do_rsync $NODE;
#     rsync_admin_module $NODE;
done




