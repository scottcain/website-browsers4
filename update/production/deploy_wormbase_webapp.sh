#!/bin/bash

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



# Log onto each node and update code
alert "Checking out code into production..."
for NODE in ${OICR_SITE_NODES}
do
    alert "   checking out code on $NODE...";
    # hg pull and update
    ssh $NODE "cd /usr/local/wormbase/website/production; hg pull -u "

    # I should test at the same time, then restart apache and the socket server...
    # hg pull -u && prove -l t && sudo /etc/init.d/apache2 restart

    # Restart starman
    ssh $NODE "cd /usr/local/wormbase/website/production; bin/starman-generic.sh production restart"

    # Installing modules
#    ssh $NODE "cd /usr/local/wormbase/website/production; source wormbase.env; perl Makefile.PL; make installdeps"




   
done




exit

# Rsync the library directory from staging to each individual node
#cd /usr/local/wormbase/website
#rsync -Cav extlib/ $NODE:/usr/local/wormbase/website/extlib/








