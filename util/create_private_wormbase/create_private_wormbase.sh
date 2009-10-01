#!/bin/sh

# This is a simple script to quickly create a private
# WormBase repository

PERSON=$1
PORT=$2
WD=`pwd`
mkdir ${PERSON}
chmod 2775 ${PERSON}
cd ${PERSON}
CURRENTWD=`pwd`
cvs co wormbase-site
mv wormbase-site/* .
rm -rf wormbase-site
cp conf/perl.startup.template conf/perl.startup
cp conf/localdefs.pm.template conf/localdefs.pm

# Fix the primary httpd.conf file for the server and the apachetl script
cp /home/tharris/projects/wormbase/admin/util/create_private_wormbase/support_files/httpd.conf.template conf/httpd.conf
#perl -p -i -e "s|Port_target|${PORT}|g" httpd.conf
#perl -p -i -e "s|/Conf_target/|${CURRENTWD}/conf/httpd.conf|g" httpd.conf
#perl -p -i -e "s|/Log_target/|${CURRENTWD}/logs/|g" httpd.conf
#perl -p -i -e "s|User_target|${PERSON}|g" httpd.conf
#perl -p -i -e "s|/Root_target/|${WD}/${PERSON}/|g" httpd.conf

# Fix a few things inthe main httpd.conf file
echo "fixing the httpd.conf file"
perl -p -i -e "s|/usr/local/wormbase/website-classic|${CURRENTWD}|g" \
    conf/elegans.pm conf/httpd.conf conf/perl.startup conf/localdefs.pm
perl -p -i -e "s|/var/tmp/ace_images|${CURRENTWD}/tmp/ace_images|g" conf/httpd.conf
perl -p -i -e "s|Expires|#Expires|g" conf/httpd.conf

# Fix error and access logs
echo "fixing logs"
mkdir logs
chmod 777 logs
perl -p -i -e "s|/usr/local/wormbase/logs/classic-error_log|${CURRENTWD}/logs/classic-error_log|g" conf/httpd.conf
perl -p -i -e "s|/usr/local/wormbase/logs/classic-access_log|${CURRENTWD}/logs/classic_access_log|g" conf/httpd.conf

# Fix perl.startup
echo "fixing perl.startup"
cp /usr/local/wormbase/website-classic/conf/perl.startup conf/perl.startup
perl -p -i -e "s|/usr/local/wormbase/website-classic|{$CURRENTWD}|g" conf/perl.startup

# apachectl should point to the main httpd.conf file
echo "fixing apachectl"
cp /home/tharris/projects/wormbase/admin/util/create_private_wormbase/support_files/apachectl.template apachectl
perl -p -i -e "s|/Root_target/|${WD}/${PERSON}/|g" apachectl

# Get the index page
echo "getting the index page"
cp /usr/local/wormbase/website-classic/html/index.html html/.

# Update the external libraries path
echo "fixing the extlib path"
rm -rf extlib
ln -s /usr/local/wormbase/website-classic/extlib extlib

# Fix the localdefs
echo "fixing localdefs"
perl -p -i -e "s|/usr/local/wormbase|${CURRENTWD}|g" conf/localdefs.pm

# Set up the cache
echo "setting up the cache"
mkdir cache
chmod 777 cache

# Get the structure images
echo "mirroring structure images"
cp -r /usr/local/wormbase/website-classic/html/images/structure-images html/images/.

echo "/usr/local/apache2/bin/httpd -f ${CURRENTWD}/conf/httpd.conf -k start -c \"Port ${PORT}\"" >> start_wormbase.sh
chmod 755 start_wormbase.sh
mkdir -p tmp/ace_images
chmod -R 777 tmp logs cache

echo "fixing permissions"
cd ${WD}
sudo chown -R ${PERSON}:wormbase ${PERSON}
