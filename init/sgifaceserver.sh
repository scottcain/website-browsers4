#!/bin/bash

case $1 in
start)
  echo $$ > /usr/local/acedb/sgifaceserver.pid;

  # Clean out serverlog.wrm, log.wrm, and readlocks.wrm
  rm -rf /usr/local/acedb/elegans/database/log.wrm
  rm -rf /usr/local/acedb/elegans/database/serverlog.wrm
  rm -rf /usr/local/acedb/elegans/database/readlocks

  exec 2>&1 /usr/local/acedb/bin/sgifaceserver /usr/local/acedb/elegans 2005 1200:1200:100
;;
stop)
  kill `cat /usr/local/acedb/sgifaceserver.pid` ;;
*)
  echo "usage: sgifaceserver.sh {start|stop}"
;;
esac
