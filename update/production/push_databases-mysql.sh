#!/bin/bash

export RSYNC_RSH=ssh
VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

LOCAL_MYSQL_DATA_DIR=/var/lib/mysql

# For now, the old mysql data dir on the remote servers does not map to the same space as development
REMOTE_MYSQL_DATA_DIR=/usr/local/mysql/data
MYSQL_NODES=`cat conf/nodes_mysql.conf`
MYSQL_NODES=("brie6.cshl.edu be1.wormbase.org vab.wormbase.org 
              gene.wormbase.org blast.wormbase.org  aceserver.cshl.edu")
MYSQL_DATABASES=("c_brenneri
                  c_briggsae 
                  c_elegans 
                  c_elegans_gmap 
                  c_elegans_pmap 
                  c_remanei 
                  c_japonica 
                  p_pacificus
                  clustal
")

#                  nbrowse_wormbase
# autocomplete

MYSQL_OLD_DATABASES=("briggsae elegans elegans_pmap elegans_gmap")

SEPERATOR="==========================================="

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



alert "Pushing mysql databases onto mysql nodes..."
for NODE in ${MYSQL_NODES}
do
  alert " ${NODE}:"
  for DB in ${MYSQL_DATABASES} 
  do
    TARGET=${DB}_${VERSION}
    if rsync -Ca --exclude *bak* ${LOCAL_MYSQL_DATA_DIR}/${TARGET} ${NODE}:${REMOTE_MYSQL_DATA_DIR}
    then
      success "Successfully pushed ${DB} onto ${NODE}"
      
      # Set up appropriate symlinks and permissions
      if ssh ${NODE} "cd ${REMOTE_MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}"
      then
	  success "Successfully symlinked ${DB} -> ${TARGET}"
      else
	  failure "Symlinking failed"
      fi

      # Fix permissions
      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql ${TARGET}"
      then
	  success "Successfully fixed permissions on ${TARGET}"
      else
	  failure "Fixing permissions on ${TARGET} failed"
      fi

    else
	failure "Pushing ${DB} onto ${NODE} failed"
    fi
  done

#for DB in ${MYSQL_OLD_DATABASES} 
#    TARGET=${DB}_${VERSION}
#      # Old style symlinks. Deprecated with WS192
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm ${DB};  ln -s ${TARGET} ${DB}"
#      then
#	  success "Successfully symlinked ${DB} -> ${TARGET}"
#      else
#	  failure "Symlinking failed"
#      fi
#done


# Other static databases. Not necessary - just a convenience to ensure they are in place
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/c_japonica_3 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed c_japonica onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm c_japonica;  ln -s c_japonica_3 c_japonica"
#      then
#	  success "Successfully symlinked c_japonica -> c_japonica_3"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql c_japonica_3"
#      then
#	  success "Successfully fixed permissions on c_japonica_3"
#      else
#	  failure "Fixing permissions on c_japonica_3 failed"
#      fi
#fi

done

exit



# None of this is necessary any longer
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/c_brenneri_4 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed c_brenneri onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm c_brenneri;  ln -s c_brenneri_4 c_brenneri"
#      then
#	  success "Successfully symlinked c_brenneri -> c_brenneri_4"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql c_brenneri_4"
#      then
#	  success "Successfully fixed permissions on c_brenneri_4"
#      else
#	  failure "Fixing permissions on c_brenneri_4 failed"
#      fi
#fi
#
#
#if rsync -Ca --exclude *bak* ${MYSQL_DATA_DIR}/b_malayi_bma1 ${NODE}:${MYSQL_DATA_DIR}
#    then
#      success "Successfully pushed b_malayi onto ${NODE}"
#      
#      # Set up appropriate symlinks and permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; rm b_malayi;  ln -s b_malayi_bma1 b_malayi"
#      then
#	  success "Successfully symlinked b_malayi -> b_malayi_bma1"
#      else
#	  failure "Symlinking failed"
#      fi
#
#      # Fix permissions
#      if ssh ${NODE} "cd ${MYSQL_DATA_DIR}; chown -R todd:mysql b_malayi_bma1"
#      then
#	  success "Successfully fixed permissions on b_malayi_bma1"
#      else
#	  failure "Fixing permissions on b_malayi_bma1 failed"
#      fi
#fi
#
#
#done






