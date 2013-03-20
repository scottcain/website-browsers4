#!/bin/sh

#########################################
# Concatenate the logs for this release
#########################################

RELEASE=$1
PURGE_SCRIPT=$2
BINDIR=/usr/local/website-admin/log_maintenance/analysis
LOGDIR=/usr/local/acedb/wormbase_log_archive
JDRESOLVE=${BINDIR}/jdresolve
TARGET=/usr/local/wormbase/html/stats
STATS_HOST=brie6.cshl.org
YEAR=`date +%Y`
BACK=`date +%m-%d-%Y`

#if [ -e ${PURGE_SCRIPT} ]
#then 
#  echo "OK.  Purge script found..."
#else
#  wget http://toddot.net/purge_logs_enhanced.pl
PWD=`pwd`
PURGE_SCRIPT=${PWD}/purge_squid_logs.pl
if [ -e ${PURGE_SCRIPT} ]
  then
    echo "OK. Purge script fetched and at ${PURGE_SCRIPT}"
    chmod 755 ${PURGE_SCRIPT}
  else 
    echo "The purge script could not be found..."
   exit 0;
  fi
#fi

#exit;

if [ ${RELEASE} ]
then 
  echo "Concatenating logs for ${RELEASE}"
else 
 echo "Usage: concatenate_logs.sh WSXXX [PURGE] (where WSXXX is the current live release and PURGE is the full path to a squid purging script)"
 exit 0;
fi

###################################
####### ORIGIN SERVER LOGS ########
###################################
# Move current logs into the archive so that I can work with them
# These are now direct requests to the origin httpd
# We will actually use the squid logs for our analysis
#cd /usr/local/wormbase/logs
#cp access_log* archive/raw/.
#cp error_log* archive/raw/.
#cd /usr/local/wormbase/logs/archive/raw

# Not really necessary any longer.  The squid logs are where all data is
## Access logs (need to move access_log so gzipped archive doesn't obliterate it)
#mv access_log access_log.0
#gunzip access_log.gz
#mv access_log access_log.8
#cat access_log.8 access_log.7 access_log.6 access_log.5 access_log.4 access_log.3 access_log.2 \
#   access_log.1 access_log.0 > access_log.${RELEASE}.httpd
#gzip access_log.${RELEASE}.httpd
#
## Delete the old logs
#rm -rf access_log.0 access_log.1 access_log.2 access_log.3 access_log.4 access_log.5 \
#       access_log.6 access_log.7 access_log.8           


##################################
########## SQUID LOGS ############
##################################
# Concatenate the squid logs which truly reflect access stats
# Fetch the current squid logs from fe.wormbase.org


cd ${LOGDIR}/raw
cp /usr/local/squid/logs/access_log* .

sudo chown todd access_log*
mv access_log access_log.0
gunzip access_log.gz
mv access_log access_log.8
cat access_log.8 access_log.7 access_log.6 access_log.5 access_log.4 access_log.3 access_log.2 \
   access_log.1 access_log.0 > access_log.${RELEASE}.full_squid

${PURGE_SCRIPT} access_log.${RELEASE}.full_squid > access_log.${RELEASE}

## Compress the logs
gzip access_log.${RELEASE}
gzip access_log.${RELEASE}.full_squid

# Concatenate these to the cumulative log
cp access_log.${YEAR}.gz access_log.${YEAR}.${BACK}.bak
cat access_log.${RELEASE}.gz >> access_log.${YEAR}.gz

# Delete the old logs
rm -rf access_log.0 access_log.1 access_log.2 access_log.3 access_log.4 access_log.5 \
       access_log.6 access_log.7 access_log.8  

################################
########## Error logs ##########
################################
#cd /usr/local/wormbase/logs/archive/raw
#mv error_log error_log.0
#gunzip error_log.gz
#mv error_log error_log.8
#cat error_log.8 error_log.7 error_log.6 error_log.5 error_log.4 error_log.3 error_log.2 \
#    error_log.1 error_log.0 > error_log.${RELEASE}
#gzip error_log.${RELEASE}
#
#rm -rf error_log.8 error_log.7 error_log.6 error_log.5 error_log.4 error_log.3 error_log.2 \
#       error_log.1 error_log.0


################################
# Add hostnames
################################
echo "Adding hostnames..."
#${BINDIR}/add_hostnames.pl \
#  ${LOGDIR}/raw/access_log.${RELEASE}.gz \
#  | gzip -c > ${LOGDIR}/with_hosts/access_log.${RELEASE}.gz

# Now using jdresolve
gunzip -c ${LOGDIR}/raw/access_log.${RELEASE}.gz | ${JDRESOLVE}/jdresolve -s 16 -l 300000 -r - | gzip -c > ${LOGDIR}/with_hosts/access_log.${RELEASE}.gz

## Concatenate the current release to the cumulative log
cd ${LOGDIR}/with_hosts/

# Back up the cumulative log FIRST
cp access_log.${YEAR}.gz access_log.${YEAR}.gz.${BACK}.bak
cat access_log.${RELEASE}.gz >> access_log.${YEAR}.gz


#####################################
# Rsync the stats directory to brie6
#####################################
#rsync -avz ${LOGDIR}/raw/ ${STATS_HOST}:/usr/local/acedb/wormbase_log_archive/raw
rsync -avz ${LOGDIR}/with_hosts/ ${STATS_HOST}:/usr/local/acedb/wormbase_log_archive/with_hosts


#rm -f ${PURGE_SCRIPT}
