#!/bin/bash

# Pull in my configuration variables shared across scripts
source /home/tharris/projects/wormbase/wormbase-admin/update/production/update.conf

export RSYNC_RSH=ssh
wormbase_version=$1
minor_revision=$2

if [ ! "${wormbase_version}" ]
then
  echo "Usage: $0 WSXXX [1] // WormBase version that is going live; boolean to indicate minor revision"
  exit
fi

date=`date +%Y%m%d`

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


# Get the current version of the production software.
# by extracting it from Web.pm
function extract_version_from_pm() {
   this_version_string=`grep  VERSION /usr/local/wormbase/website/staging/lib/WormBase/Web.pm`
   software_version=`expr match "${this_version_string}" "our \\$VERSION = '\(....\)'"`
}

# Or extract version by reading a symlink (deprecated)
function extract_version_by_symlink() {
    this_link=`readlink /usr/local/wormbase/website/production`
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

    if ssh ${node} "cd /usr/local/wormbase/website/${dir}; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\[% app %\]/production/g' wormbase.env"
    then
	success "Successfully created the environment file on $node at $dir/wormbase.env"
    else 
	failure "Creating wormbase.env file failed"
    fi
}

function restart_services() {
    node=$1

    # Restart starman.  Here or in the go live script?
    echo "Restarting starman on $node..."
    ssh $node "cd /usr/local/wormbase/website/production; source wormbase.env ; bin/starman-production.sh restart"
}




function do_rsync() {
    node=$1

#    dir=${wormbase_version}-v${software_version}.${hg_revision}-${date}
    dir=${wormbase_version}-${date}-v${software_version}r${hg_revision}

    # Name of our directory in production. By default, this is tied to
    #   the version of the database
    #   the date of the release
    #   the version of the software
    #   and the most current changeset.  Whew!
    target=${dir}
 
    cd /usr/local/wormbase/website
  
    # Before syncing, dump a small file with these versions.
    touch VERSION.txt
    cat /dev/null > VERSION.txt
    cat > VERSION.txt <<EOF
DATE=${date}
DATABASE_VERSION=${wormbase_version}
SOFTWARE_VERSION=${software_version}
CHANGESET=${hg_revision}
EOF

    alert " Updating ${node} to ${dir}..."

    # Rsync this 
    ssh ${node} mkdir /usr/local/wormbase/website/${target}

    # Rsync the diretory to the new target dir
    if rsync -Ca --exclude logs --exclude tmp --exclude .hg --exclude extlib.tgz --exclude extlib staging/ ${node}:/usr/local/wormbase/website/${target}
    then
	success "Successfully pushed webapp ${software_version} onto ${node}"

	
	# Copy extlib, either as a directory or compressed
#	scp -r staging/extlib ${node}:/usr/local/wormbase/website/${target}/.
	cd /usr/local/wormbase/website/staging
	scp -r extlib.tgz ${node}:/usr/local/wormbase/website/${dir}/.
	ssh $node "cd /usr/local/wormbase/website/${dir} ; tar xzf extlib.tgz "
	
	# Establish log directories, remove and re-symlink
	# I should run tests BEFORE updating the symlink, to trap cases like where we have missing modules.
	
        # eg: hg pull -u && prove -l t && sudo /etc/init.d/apache2 restart

        # Installing modules
        # ssh $NODE "cd /usr/local/wormbase/website/production; source wormbase.env; perl Makefile.PL; make installdeps"

	if ssh ${node} "cd /usr/local/wormbase/website; mkdir ${target}/logs ; chmod 777 ${target}/logs ; rm production;  ln -s ${dir} production"
	    
	then
	    success "Successfully symlinked production -> ${dir}"
	    update_env_template $node $target
	else
	    failure "Symlinking failed"
	fi
    fi    
}



# Get the current (major) version of the production software.
extract_version_from_pm

# Get the current changeset of the production software.
extract_version_from_hg

# Do some prep work
alert "Compressing libraries for replication..."
cd /usr/local/wormbase/website/staging
tar czf extlib.tgz extlib


# 1. Rsync the production version to remote and local production nodes
######################################################
#
#    OICR 
#
######################################################
alert "Deploying current version production code (${software_version}) onto OICR nodes..."

for node in ${OICR_SITE_NODES}
do
    do_rsync $node
    # do_tests $node
    # restart_services $node
done


######################################################
#
#    REMOTE SITE NODES
#
######################################################
alert "Deploying current version production code (${software_version}) onto remote nodes..."

for node in ${REMOTE_SITE_NODES}
do
    do_rsync $node
    # do_tests $node
    # restart_services $node
done


######################################################
#
#    CREATE A SOFTWARE RELEASE
#
######################################################

if [ $minor_revision ]
then
    # Although: we might want to for mirroring purposes...
    echo "minor revision; not creating software release..."
else 

# 2. Copy the production version to the releases archive and the ftp site
    cd /usr/local/wormbase/website
    
    # Create a release on the ftp site    
    date=`date +%Y-%m-%d`
    dir=${wormbase_version}-${date}-v${software_version}r${hg_revision}

    cp -r staging /usr/local/ftp/pub/wormbase/software/${dir}
    cd /usr/local/ftp/pub/wormbase/software
    tar czf ${dir}.tgz \
	    ${dir} \
        --exclude "logs" \
        --exclude ".hg" \
        --exclude "extlib" \
	--exclude "wormbase_local.conf"
    rm -rf ${dir}
    rm current.tgz
    ln -s ${dir}.tgz current.tgz
fi
    

######################################################
#
#    DO SOME CLEANUP
#
######################################################

cd /usr/local/wormbase/website/staging
rm -rf extlib.tgz

# 3. Remove the old production version on the development site
cd /usr/local/wormbase/website
rm -rf production
    
# 4. Save a new reference version of production on the development site
cp -r staging production

exit;





