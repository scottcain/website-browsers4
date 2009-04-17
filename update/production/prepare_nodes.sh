#!/bin/bash

NODES=`cat conf/nodes_all.conf`
MYSQL_DATA_DIR=/usr/local/mysql/data

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

alert "Preparing nodes for update..."
for NODE in ${NODES}
do
  alert " ${NODE}:"

  # Check for appropriate disk space
  ssh ${NODE} df -h
  # Prompt the user for input
  echo "Is there sufficient space on ${NODE} to continue?"
  select yn in "Yes" "No"; do
      case $yn in
	  Yes ) break;;
	  No  ) echo "Clear off some disk space, then relaunch..."; exit;;
      esac
  done
  
  # Fix permissions on the mysql data dir
  ssh ${NODE} chmod 2775 ${MYSQL_DATA_DIR}
done
