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
cp /usr/local/wormbase-admin/general_admin/create_private_wormbase/support_files/apachectl.template apachectl
cp /usr/local/wormbase-admin/general_admin/create_private_wormbase/support_files/httpd.conf.template httpd.conf

# Fix the primary httpd.conf file for the server and the apachetl script
perl -p -i -e "s|Port_target|${PORT}|g" httpd.conf
perl -p -i -e "s|/Conf_target/|${CURRENTWD}/conf/httpd.conf|g" httpd.conf
perl -p -i -e "s|/Log_target/|${CURRENTWD}/logs/|g" httpd.conf
perl -p -i -e "s|User_target|${PERSON}|g" httpd.conf
#perl -p -i -e "s|/Root_target/|${WD}/${PERSON}/|g" httpd.conf

# Fix a few things inthe main httpd.conf file
perl -p -i -e "s|/usr/local/wormbase|${CURRENTWD}|g" \
    conf/elegans.pm conf/httpd.conf conf/perl.startup conf/localdefs.pm
perl -p -i -e "s|/var/tmp/ace_images|${CURRENTWD}/tmp/ace_images|g" conf/httpd.conf
perl -p -i -e "s|Expires|#Expires|g" conf/httpd.conf

# apachectl should point to the main httpd.conf file
perl -p -i -e "s|/Root_target/|${WD}/${PERSON}/|g" apachectl

echo "/usr/local/apache/bin/httpd -f ${CURRENTWD}/conf/httpd.conf -k start -c \"Port ${PORT}\"" >> start_wormbase.sh
chmod 755 start_wormbase.sh
mkdir -p tmp/ace_images
chmod -R 777 tmp logs cache

cd ${WD}
sudo chown -R ${PERSON}:wormbase ${PERSON}

