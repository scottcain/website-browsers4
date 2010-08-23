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
   ssh $NODE "cd /usr/local/wormbase/website; hg pull -u "
#    ssh $NODE "cd /usr/local/wormbase/website; hg pull -u ; /etc/init.d/wormbase-fastcgi stop ; rm -rf /tmp/wormbase/WormBase* ; /etc/init.d/wormbase-fastcgi start"
#    ssh -vv $NODE "/etc/init.d/wormbase-fastcgi stop ; rm -rf /tmp/wormbase/WormBase* ; /etc/init.d/wormbase-fastcgi start"

    # I should test at the same time, then restart apache and the socket server...
    # hg pull -u && prove -l t && sudo /etc/init.d/apache2 restart
   
done


exit

# Rsync the library directory from staging to each individual node
#cd /usr/local/wormbase/website
#rsync -Cav extlib/ $NODE:/usr/local/wormbase/website/extlib/





exit


# Installing modules
cd /usr/local/wormbase/website-2.0
mkdir extlib
cd extlib
perl -Mlocal::lib=./
eval $(perl -Mlocal::lib=./)

cd ../
perl Makefile.PL
make installdeps






