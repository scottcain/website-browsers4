#!/bin/bash

# Restart wormbase services across nodes

# Pull in my configuration variables shared across scripts
source ../update/production/update.conf



#VERSION=$1
#
#if [ ! "$VERSION" ]
#then
#  echo "Usage: $0 WSXXX"
#  exit
#fi

# What is my gateway host?
GATEWAY_HOST=${STAGING_NODE}

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


##############################################
#
#  Restart AceDB on the ACEDB_NODES
#
##############################################
alert "Restarting sigfaceserver and xinetd services for acedb nodes..."
for NODE in ${ACEDB_NODES}
do
  alert "${NODE}"  

  # The GATEWAY HOST
  if [ "${NODE}" = "brie3.cshl.org" ]; then
      if ssh -t ${GATEWAY_HOST} "sudo killall -9 sgifaceserver"
      then
	  success "sgifaceserver restarted on ${NODE}"
	  sleep 5
	  if ssh -t ${GATEWAY_HOST} "sudo /etc/rc.d/init.d/xinetd restart"
	  then
	      success "xinetd restarted on ${NODE}"
	  else
	      failure "sgifaceserver / xinetd could not be restarted on ${NODE}"
	  fi
      fi
     
  else 
      # Restart sgifaceserver on the other nodes by tunneling throughthe gateways
      
      #  if ssh ${NODE} "sudo kill -9 `ps -C sgifaceserver -o pid=`"
      if ssh -t ${GATEWAY_HOST} "ssh -t ${NODE} sudo killall -9 sgifaceserver"
      then
	  success "sgifaceserver restarted on ${NODE}"
	  sleep 5
	  if ssh -t ${GATEWAY_HOST} "ssh -t ${NODE} sudo /etc/rc.d/init.d/xinetd restart"
	  then
	      success "xinetd restarted on ${NODE}"
	  else
	      failure "sgifaceserver / xinetd could not be restarted on ${NODE}"
	  fi
      fi
  fi

done



##############################################
#
#  Restarting mysqld adn httpd on nodes
#
##############################################

alert "Restarting mysql and httpd for all nodes..."
# First the gateway host
if ssh -t ${GATEWAY_HOST} "sudo /etc/rc.d/init.d/mysqld restart"
then
    success "mysqld successfully restarted on ${GATEWAY_HOST}"
else
    failure "mysqld could not be restart on ${GATEWAY_HOST}"
fi

if ssh -t ${GATEWAY_HOST} "sudo /usr/local/apache2/bin/apachectl restart"
then
    success "httpd succesfully restarted on ${GATEWAY_HOST}"
else
    failure "httpd could not be restarted on ${GATEWAY_HOST}"
fi

# Now on the remaining site nodes
for NODE in ${SITE_NODES}
do
  alert "${NODE}"  
  if ssh -t ${GATEWAY_NODE} "ssh -t ${NODE} sudo /etc/rc.d/init.d/mysqld restart"
      then
      success "mysqld successfully restarted on ${NODE}"
  else
      failure "mysqld could not be restarted on ${NODE}"
  fi
  
  if ssh -t ${GATEWAY_NODE} "ssh -t ${NODE} sudo /usr/local/apache2/bin/apachectl restart"
      then
      success "httpd succesfully restarted ${NODE}"
  else
      failure "httpd could not be restarted ${NODE}"
  fi
done

