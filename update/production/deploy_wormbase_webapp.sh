#!/bin/bash

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

export RSYNC_RSH=ssh
wormbase_version=$1
minor_revision=$2

if [ ! "${wormbase_version}" ]
then
  echo "Usage: $0 WSXXX (WormBase version that is going live)"
  exit
fi

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


# Get the current version of the staging software.
# by extracting it from Web.pm
function extract_version_from_pm() {
   this_version_string=`grep  VERSION /usr/local/wormbase/website/staging/lib/WormBase/Web.pm`
   software_version=`expr match "${this_version_string}" "our \\$VERSION = '\(....\)'"`
}

# Or extract version by reading a symlink (deprecated)
function extract_version_by_symlink() {
    this_link=`readlink /usr/local/wormbase/website/staging`
    echo "Pushing software version ${this_link} into production"
}

# Or maye read the HG version...

function do_rsync() {
    node=$1
    software_version=$2
    alert " Updating ${node} to ${software_version}..."

    # Rsync this 
    cd /usr/local/wormbase/website
    if rsync -Cav --exclude logs --exclude tmp --exclude .hg staging ${node}:/usr/local/wormbase/website
    then
	success "Successfully pushed webapp ${software_version} onto ${node}"
	
	# Set up appropriate symlinks ad log directories
	if ssh ${node} "cd /usr/local/wormbase/website; mv staging ${software_version} ; mkdir ${software_version}/logs ; chmod 777 ${software_version}/logs ; rm production;  ln -s ${software_version} production"
	then
	    success "Successfully symlinked production -> ${software_version}"
	else
	    failure "Symlinking failed"
	fi
    fi
}


# Get the current version of the staging software
extract_version_from_pm

# Rsync for minor revisions
function do_minor_rsync() {
    node=$1
    software_version=$2
    alert " Minor revision to ${node} to ${software_version}..."

    # Rsync this 
    cd /usr/local/wormbase/website
    if rsync -Cav --exclude logs --exclude tmp --exclude .hg staging/ ${node}:/usr/local/wormbase/website/${software_version}/
    then
	success "Successfully pushed webapp ${software_version} onto ${node}"       
    fi
}




if [ $minor_revision ]
then
    alert "Deploying current version staging code (${software_version}) onto OICR nodes..."
    for NODE in ${OICR_SITE_NODES}
    do
	echo "   rsyncing...";
	do_minor_rsync $NODE $software_version
    done
    
    alert "Deploying current version staging code (${software_version}) onto remote nodes..."
    for NODE in ${REMOTE_SITE_NODES}
    do
	echo "   rsyncing...";
	do_minor_rsync $NODE $software_version
    done
    exit
fi
    


# 1. Rsync the staging version to remote and local production nodes

######################################################
#
#    OICR 
#
######################################################
alert "Deploying current version staging code (${software_version}) onto OICR nodes..."
for NODE in ${OICR_SITE_NODES}
do
echo "   rsyncing...";
    do_rsync $NODE $software_version
done


######################################################
#
#    REMOTE SITE NODES
#
######################################################
alert "Deploying current version staging code (${software_version}) onto remote nodes..."
for NODE in ${REMOTE_SITE_NODES}
do
echo "   rsyncing...";
    do_rsync $NODE $software_version
done


# 2. Copy the staging version to the releases archive and the ftp site
cd /usr/local/wormbase/website
mkdir releases
date=`date +%Y-%m-%d`
cp -r staging releases/${wormbase_version}-${software_version}-${date}
#cp -r staging /usr/local/ftp/pub/wormbase/software/${wormbase_version}-${software_version}-${date}
#cd /usr/local/ftp/pub/wormbase/software/${wormbase_version}-${software_version}-${date}.tgz ${wormbase_version}-${software_version}-${date}

# 3. Remove the old production version
cd /usr/local/wormbase/website
rm -rf production

# 4. Save a new reference version of production
cp -r staging production


exit;




# OLD APPROACH

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








