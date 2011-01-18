#!/bin/bash

# Restart wormbase services across nodes
export RSYNC_RSH=ssh
DO_RESTART=$1

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf


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

function restart_sgifaceserver() {
    NODE=$1
    alert "${NODE}"
    
#  if ssh ${NODE} "sudo kill -9 `ps -C sgifaceserver -o pid=`"
    if ssh -t ${NODE} "sudo killall -9 sgifaceserver"
    then
	success "sgifaceserver restarted"
#      if ssh -t ${NODE} "sudo /etc/rc.d/init.d/xinetd restart"
	if ssh -t ${NODE} "sudo /etc/init.d/xinetd restart"
	then
	    success "xinetd restarted"
	else
	    failure "sgifaceserver / xinetd could not be restarted"
	fi
    fi
}

function restart_mysqld() {
    NODE=$1
    alert "${NODE}"
#    if ssh -t ${NODE} "sudo /etc/rc.d/init.d/mysqld restart"
    if ssh -t ${NODE} "sudo /etc/init.d/mysql restart"
    then
	success "mysqld successfully restarted"
    else
	failure "mysqld could not be restart"
    fi
    
    if ssh -t ${NODE} "sudo /usr/local/apache2/bin/apachectl restart"
    then
	success "httpd succesfully restarted"
    else
	failure "httpd could not be restarted"
    fi
}

function restart_starman() {
    NODE=$1
    alert "${NODE}"
    if ssh -t ${NODE} "/usr/local/wormbase/admin/monitoring/restart_starman.sh"
    then
	success "starman successfully restarted"
    else
	failure "starman could not be restarted"
    fi
}



function restart_httpd() {
    if ssh -t ${NODE} "sudo /usr/local/apache2/bin/apachectl restart"
    then
	success "httpd succesfully restarted"
    else
	failure "httpd could not be restarted"
    fi
}





# ACedb nodes need to have sgifaceserver killed
# and xinetd restarted
alert "Restarting sigfaceserver and xinetd services for acedb nodes..."
ACEDB_NODES=( ${OICR_ACEDB_NODES[@]} ${REMOTE_ACEDB_NODES[@]} )
for NODE in ${ACEDB_NODES[@]}
do
#    restart_sgifaceserver $NODE
    echo $NODE
done


# Mysql nodes: restart mysql and httpd
alert "Restarting mysql and httpd for all nodes..."
MYSQL_NODES=( ${OICR_MYSQL_NODES[@]} ${REMOTE_MYSQL_NODES[@]} )
for NODE in ${MYSQL_NODES[@]}
do
    restart_mysqld $NODE
    restart_httpd $NODE
done


