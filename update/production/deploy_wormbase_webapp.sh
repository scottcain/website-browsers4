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

# Or get the current version of tip from hg. EVERY push to the website will be a new version.
function extract_version_from_hg() {
    cd /usr/local/wormbase/website/staging
    hg_revision=`hg tip --template '{rev}'`
}


# Create the appropriate env template
function update_env_template() {
    node=$1
    dir=$2
    
    # Set up appropriate symlinks and log directories
    if ssh ${node} "cd /usr/local/wormbase/website/${dir}; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\[% app %\]/production/g' wormbase.env"
    then
	success "Successfully created the environment file on $node at $dir/wormbase.env"
    else 
	failure "Creating wormbase.env file failed"
    fi
}

function do_rsync() {
    node=$1

    date=`date +%Y.%m.%d`
    dir=${wormbase_version}-$date-${software_version}-${hg_revision}

    #software_version=$2
    alert " Updating ${node} to ${dir}..."

    # Rsync this 
    cd /usr/local/wormbase/website
    if rsync -Cav --exclude logs --exclude tmp --exclude .hg staging ${node}:/usr/local/wormbase/website
    then
	success "Successfully pushed webapp ${software_version} onto ${node}"
	
	# Set up appropriate symlinks and log directories
	if ssh ${node} "cd /usr/local/wormbase/website; mv staging ${dir} ; mkdir ${dir}/logs ; chmod 777 ${dir}/logs ; rm production;  ln -s ${dir} production"
	then
	    success "Successfully symlinked production -> ${dir}"
	    update_env_template $node $dir
	else
	    failure "Symlinking failed"
	fi
    fi
}



# Get the current version of the staging software
extract_version_from_pm
extract_version_from_hg

# 1. Rsync the staging version to remote and local production nodes
######################################################
#
#    OICR 
#
######################################################
alert "Deploying current version staging code (${software_version}) onto OICR nodes..."
for NODE in ${OICR_SITE_NODES}
do
    do_rsync $NODE
done


######################################################
#
#    REMOTE SITE NODES
#
######################################################
alert "Deploying current version staging code (${software_version}) onto remote nodes..."
for NODE in ${REMOTE_SITE_NODES}
do
    do_rsync $NODE
done


if [ $minor_revision ]
then
    # Although: we might want to for mirroring purposes...
    echo "minor revision; not creating software release..."
else 

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
fi
    
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








