#!/bin/sh

################################################
# Concatenate WormBase logs on a monthly basis
################################################

DEBUG=

BINDIR=/home/todd/projects/wormbase/admin/log_analysis
LOGDIR=/usr/local/acedb/wormbase_log_archive
PURGE_SCRIPT=${BINDIR}/purge_squid_logs.pl

JDRESOLVE=${BINDIR}/jdresolve
TARGET=/usr/local/wormbase/html/stats
#STATS_HOST=brie6.cshl.org
#USER=todd
STATS_HOST=wb-dev.oicr.on.ca
STATS_USER=tharris

# Who should we execute non-privileged commands as on the server
# where the logs reside?
USER=todd
YEAR=`date +%Y`
DATE=`date +%Y.%m`
#DATE=`date +%Y.%m.%d`
#DATE=`date %m-%d-%Y`


# Is this the last day of the month?
# IE is tomorrow in a different month?
# If so, let's concatenate logs.
# This isn't perfect since cron has minute interval.
# The range will start with some requests from the previous month
# but end on the last day of the month.
todayMonth=`date +%m`
tomorrowMonth=`perl -e '@T=localtime(time+86400);printf("%02d",$T[4]+1)'`

#tomorrowMonth=13

if [ $tomorrowMonth != $todayMonth ]; then

  echo "Analyzing WormBase logs for ${DATE}"

  # Concatenate logs from the previous month.
  # This isn't prefect since the cron job runs
  # at 23:59 on the last day of the month.
  cd ${LOGDIR}/raw
  cp /usr/local/squid/logs/access_log* .

  # Reset the squid cache
  if [ ! ${DEBUG} ]; then
    /etc/rc.d/init.d/squid fullreset
  fi

  # Fetch the current logs and extract
  mv access_log access_log.0
  gunzip access_log.gz
  mv access_log access_log.8

  cat access_log.8 access_log.7 access_log.6 access_log.5 access_log.4 access_log.3 access_log.2 \
     access_log.1 access_log.0 | sudo -u ${USER} gzip -c > squid/access_log.${DATE}.full_squid.gz

  # Purge squid access codes into a new file
  sudo -u ${USER} ${PURGE_SCRIPT} squid/access_log.${DATE}.full_squid.gz | \
      sudo -u ${USER} gzip -c >  access_log.${DATE}.gz

  # Fix permissions on the logs
  sudo chown ${USER} access_log.${DATE}.gz
  sudo chown ${USER} squid/access_log.${DATE}.full_squid.gz

  # Create the full yearly log if it doesn't already exist
  if [ ! -r access_log.${YEAR}.gz ]; then
     sudo -u ${USER} touch access_log.${YEAR}
     sudo -u ${USER} gzip access_log.${YEAR}
  fi

  # Create a backup and fix permissions
  cp access_log.${YEAR}.gz access_log.${DATE}.before_concatenation.bak.gz
  chown ${USER} access_log.${DATE}.before_concatenation.bak.gz

  # Concatenate the current month to the current year raw archive
  if [ ! ${DEBUG} ]; then
    sudo -u ${USER} cat access_log.${DATE}.gz >> access_log.${YEAR}.gz
    sudo chown ${USER} access_log.${YEAR}.gz
  fi

  # Delete the old logs
  rm -rf access_log.0 access_log.1 access_log.2 access_log.3 access_log.4 access_log.5 \
         access_log.6 access_log.7 access_log.8  


  ################################
  # Add hostnames by jdresolve
  ################################
  echo "Adding hostnames..."

  sudo -u ${USER} gunzip -c ${LOGDIR}/raw/access_log.${DATE}.gz | ${JDRESOLVE}/jdresolve -s 16 -l 300000 -r - | gzip -c > ${LOGDIR}/with_hosts/access_log.${DATE}.gz

  # Concatante
  cd ${LOGDIR}/with_hosts/

  # Create the cumulative log first if it doesn't exist
  if [ ! -r access_log.${YEAR}.gz ]; then
     sudo -u ${USER} touch access_log.${YEAR}
     sudo -u ${USER} gzip access_log.${YEAR}
  fi


  # Create a backup and fix permissions
  if [ ! ${DEBUG} ]; then
    sudo -u ${USER} cp access_log.${YEAR}.gz access_log.${DATE}.before_concatenation.bak.gz
    chown ${USER} access_log.${DATE}.before_concatenation.bak.gz
  fi

  # Concatenate this month to the cumulative log
  if [ ! ${DEBUG} ]; then
    sudo -u ${USER} cat access_log.${DATE}.gz >> access_log.${YEAR}.gz
    chown ${USER} access_log.${YEAR}.gz
  fi

  ################################################
  # Rsync the stats directory to the stats host
  ################################################

  if [ ! ${DEBUG} ]; then
#    sudo -u ${USER} rsync -avz ${LOGDIR}/with_hosts/ ${USER}@${STATS_HOST}:/usr/local/acedb/wormbase_log_archive/with_hosts
    sudo -u ${USER} rsync -avz --exclude=*before_concatenation* --exclude=*.bak ${LOGDIR}/ ${STATS_USER}@${STATS_HOST}:projects/wormbase/log_archive/
#    sudo -u ${USER} rsync -avz ${LOGDIR}/raw/ ${USER}@${STATS_HOST}:/home/todd/projects/wormbase/log_archive/raw

  # Rsync to dreamhost for safe-keeping
  sudo -u todd rsync -avz --exclude=*before* --exclude=*.bak ${LOGDIR}/ tharris@kings.dreamhost.com:projects/wormbase/log_archive/

#  # Rsync to wb-dev for safe-keeping
#  sudo -u tharris rsync -avz --exclude=*before* --exclude=*.bak ${LOGDIR}/ tharris@web-dev.oicr.on.ca:projects/wormbase/log_archive/

    # Fire off the analyze_logs_by_month.sh script on a suitable macine
    sudo -u ${USER} ssh -t ${STATS_HOST} /home/${STATS_USER}/projects/wormbase/wormbase-admin/log_analysis/analysis_by_month/analyze_logs.sh ${DATE}

  # Send myself an announcement
  sudo -u todd echo "WormBase Log Analysis for ${DATE} complete. See: http://www.wormbase.org/stats/${DATE}/" | mail -s "WormBase Log Analysis: ${DATE}" toddwharris@gmail.com

  fi
fi
