#!/bin/bash

# This script pushes databases onto production nodes.
# It is intended to be run on the machine hosting the staging
# directory.  You'll need to have SSH set up appropriately 
# (both keys and config). You will also need to be a member
# of the acedb and mysql groups.

VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

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


if ./push_databases-acedb.sh ${VERSION}
then
	  alert "Successfully pushed Acedb onto all nodes..."
else
	  failure "Pushing acedb onto nodes failed..."
fi


if ./push_databases-mysql.sh ${VERSION}
then
	  alert "Successfully pushed mysql DBs onto all nodes..."
else
	  failure "Pushing mysql DBs onto nodes failed..."
fi


if ./push_support_databases.sh ${VERSION}
then
	  alert "Successfully synced the support DBs onto all nodes..."
else
	  failure "Pushing support DBs onto nodes failed..."
fi

exit;
