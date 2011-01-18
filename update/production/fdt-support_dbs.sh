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

		
echo ${FDT_JAR}	  
#java -jar ${FDT_JAR} -r ${SUPPORT_DB_DIRECTORY}/WS215 ${NODE}:${SUPPORT_DB_DIRECTORY}/WS215.test
java -jar ${FDT_JAR} -r ${SUPPORT_DB_DIRECTORY}/WS215 todd@brie3.cshl.org:${SUPPORT_DB_DIRECTORY}/WS215.test



exit;



function do_rsync() {
      NODE=$1
      alert " ${NODE}:"
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
	      --delete ${SUPPORT_DB_DIRECTORY}/ ${NODE}:${SUPPORT_DB_DIRECTORY}
  	  then
      	      success "Successfully pushed support databases onto ${NODE}"
  	  fi
      fi
}


alert "Rsyncing support databases onto local nodes..."
for NODE in ${OICR_SUPPORT_DB_NODES}
do
     do_rsync $NODE;
done

alert "Rsyncing support databases onto remote nodes..."
for NODE in ${REMOTE_SUPPORT_DB_NODES}
do
     do_rsync $NODE;
done



