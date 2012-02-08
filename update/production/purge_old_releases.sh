#!/bin/bash

# Purge old releases from backend machines

VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

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




function purge_mysql_dbs() {
    NODE=$1
    alert "Purging mysql databases from ${NODE}..."

    if ssh ${NODE} "rm -rf /usr/local/mysql/data/*_${VERSION}"
    then
	success "Successfully deleted *_${VERSION} from ${NODE}"
    fi         
}

function purge_acedb_dbs() {
    NODE=$1
    alert "Purging acedb databases from ${NODE}..."    
    
    if ssh -t ${NODE} "rm -rf /usr/local/wormbase/acedb/wormbase_${VERSION}"
    then
	success "Successfully purged /usr/local/wormbase/acedb/wormbase_${VERSION} from ${NODE}"
    fi
}

function purge_support_dbs() {
    NODE=$1
    alert "Purging support databases from ${NODE}..."    
    if ssh -t ${NODE} "rm -rf /usr/local/wormbase/databases/${VERSION}"
    then
	success "Successfully purged /usr/local/wormbase/databases/${VERSION} from ${NODE}"
    fi
}


# Purge acedb databases from local and remote hosts
ACEDB_NODES=( wb-web1.oicr.on.ca 
              wb-web2.oicr.on.ca 
              wb-web3.oicr.on.ca
              wb-web4.oicr.on.ca 
              wb-web6.oicr.on.ca
              wb-mining.oicr.on.ca
	      ec2-50-19-229-229.compute-1.amazonaws.com
	      )
for NODE in ${ACEDB_NODES[@]}
do
    purge_acedb_dbs $NODE
done


# Purge mysql databases from local and remote hosts
MYSQL_NODES=( wb-web1.oicr.on.ca 
              wb-web2.oicr.on.ca 
              wb-web3.oicr.on.ca
              wb-web4.oicr.on.ca 
              wb-web6.oicr.on.ca
              wb-mining.oicr.on.ca
	      ec2-50-19-229-229.compute-1.amazonaws.com
	      wb-gb1.oicr.on.ca
	      )
for NODE in ${MYSQL_NODES[@]}
do
    purge_mysql_dbs $NODE
done

# Purge support databases
SUPPORT_NODES=( wb-web1.oicr.on.ca 
              wb-web2.oicr.on.ca 
              wb-web3.oicr.on.ca
              wb-web4.oicr.on.ca 
              wb-web6.oicr.on.ca
              wb-mining.oicr.on.ca
	      ec2-50-19-229-229.compute-1.amazonaws.com
	      wb-gb1.oicr.on.ca
	      )
for NODE in ${SUPPORT_NODES[@]}
do
    purge_support_dbs $NODE
done




MYSQL_NODES=( wb-web1.oicr.on.ca 
              wb-web2.oicr.on.ca 
              wb-web3.oicr.on.ca
              wb-web4.oicr.on.ca 
              wb-web6.oicr.on.ca
              wb-mining.oicr.on.ca
	      ec2-50-19-229-229.compute-1.amazonaws.com
	      wb-gb1.oicr.on.ca
	      )
for NODE in ${MYSQL_NODES[@]}
do
    echo "disk space on $NODE..."
    ssh $NODE df -h
    echo ""
done