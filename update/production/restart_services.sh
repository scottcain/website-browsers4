#!/bin/bash

# Restart wormbase services across nodes


VERSION=$1

if [ ! "$VERSION" ]
then
  echo "Usage: $0 WSXXX"
  exit
fi

# These nodes host the Acedb database
ACEDB_NODES=`cat conf/nodes_acedb.conf`
# These node also need the mysql databases
MYSQL_NODES=`cat conf/nodes_mysql.conf`

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

# ACedb nodes need to have sgifaceserver killed
# and xinetd restarted
alert "Restarting sigfaceserver and xinetd services for acedb nodes..."
for NODE in ${ACEDB_NODES}
do
  alert "${NODE}"  

#  if ssh ${NODE} "sudo kill -9 `ps -C sgifaceserver -o pid=`"
  if ssh -t ${NODE} "sudo killall -9 sgifaceserver"
  then
      success "sgifaceserver restarted"
      if ssh -t ${NODE} "sudo /etc/rc.d/init.d/xinetd restart"
	  then
	  success "xinetd restarted"
      else
	  failure "sgifaceserver / xinetd could not be restarted"
      fi
  fi
done



# Mysql nodes: restart mysql and httpd
alert "Restarting mysql and httpd for all nodes..."
for NODE in ${MYSQL_NODES}
do
  alert "${NODE}"  
  if ssh -t ${NODE} "sudo /etc/rc.d/init.d/mysqld restart"
      then
      success "mysqld successfully restarted"
  else
      failure "mysqld could not be restart"
  fi

  if ssh -t ${NODE} "sudo /usr/local/apache/bin/apachectl restart"
      then
      success "httpd succesfully restarted"
  else
      failure "httpd could not be restarted"
  fi
done

