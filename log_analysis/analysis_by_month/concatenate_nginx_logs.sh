#!/bin/sh

################################################
# Concatenate WormBase logs on a monthly basis
################################################

DEBUG=

BINDIR=/usr/local/wormbase/website-admin/log_analysis
LOGDIR=/usr/local/wormbase/log_archive

JDRESOLVE=${BINDIR}/jdresolve
TARGET=/usr/local/wormbase/html/stats

# Where we back up our logs (and run analog/report magic from)
STATS_HOST=wb-dev.oicr.on.ca
STATS_USER=tharris

# Who should we execute non-privileged commands as 
# on the server where the logs reside?
USER=tharris
YEAR=`date +%Y`
DATE=`date +%Y.%m`


# Is this the last day of the month?
# IE is tomorrow in a different month?
# If so, let's concatenate logs.
# This isn't perfect since cron has minute interval.
# The range will start with some requests from the previous month
# but end on the last day of the month.
todayMonth=`date +%m`
tomorrowMonth=`perl -e '@T=localtime(time+86400);printf("%02d",$T[4]+1)'`

if [ $tomorrowMonth != $todayMonth ]; then

#if [ $todayMonth ]; then

  echo "Analyzing WormBase logs for ${DATE}"

  # Concatenate logs from the previous month.
  # This isn't perfect since the cron job runs
  # at 23:59 on the last day of the month.
  cd ${LOGDIR}/raw

  for PREFIX in beta www nginx blog wiki forum blog couchdb api
  do

      mv /usr/local/wormbase/logs/${PREFIX}/* .

      # Tell nginx to start some new logs.
      if [ ! ${DEBUG} ]; then
         kill -USR1 `cat /usr/local/wormbase/logs/nginx.pid`
      fi

      for LOG in access_log cache_log error_log
      do
          # Move the current access log out of the way.
	  #mv ${PREFIX}-${LOG} ${PREFIX}-${LOG}.0
	  mv ${LOG} ${LOG}.0

          # Unpack the archive (unpacks to *access.log)
	  gunzip ${LOG}.gz
	  mv ${LOG} ${LOG}.8

	  cat ${LOG}.8 ${LOG}.7 ${LOG}.6 ${LOG}.5 \
	      ${LOG}.4 ${LOG}.3 ${LOG}.2 ${LOG}.1 \
	      ${LOG}.0 | sudo -u ${USER} gzip -c > ${PREFIX}-${LOG}.${DATE}.gz

          # Fix permissions on the logs
	  sudo chown ${USER} ${PREFIX}-${LOG}.${DATE}.gz
      
          # Create the full yearly log if it doesn't already exist
	  if [ ! -r ${PREFIX}-${LOG}.${YEAR}.gz ]; then
	      sudo -u ${USER} touch ${PREFIX}-${LOG}.${YEAR}
	      sudo -u ${USER} gzip ${PREFIX}-${LOG}.${YEAR}
	  fi
	  
          # Create a backup and fix permissions
	  cp ${PREFIX}-${LOG}.${YEAR}.gz ${PREFIX}-${LOG}.${DATE}.before_concatenation.bak.gz
	  chown ${USER} ${PREFIX}-${LOG}.${DATE}.before_concatenation.bak.gz
      
          # Concatenate the current month to the current year raw archive
	  if [ ! ${DEBUG} ]; then
	      sudo -u ${USER} cat ${PREFIX}-${LOG}.${DATE}.gz >> ${PREFIX}-${LOG}.${YEAR}.gz
	      sudo chown ${USER} ${PREFIX}-${LOG}.${YEAR}.gz
	  fi

          # Delete the old logs
	  rm -rf ${LOG}.0 ${LOG}.1 ${LOG}.2 \
	      ${LOG}.3 ${LOG}.4 ${LOG}.5 \
              ${LOG}.6 ${LOG}.7 ${LOG}.8  


      ################################
      # Add hostnames by jdresolve
      # (This will be handled remotely)
      ################################
#      echo "Adding hostnames..."
#
#      sudo -u ${USER} gunzip -c ${LOGDIR}/raw/access_log.${DATE}.gz | ${JDRESOLVE}/jdresolve -s 16 -l 300000 -r - | gzip -c > ${LOGDIR}/with_hosts/access_log.${DATE}.gz

  # Concatante to the full year log
# 2010.09 - ON HOLD, NEED POST-PROCESSING PRIOR TO CONCATENATION
#  cd ${LOGDIR}/with_hosts/
#
#  # Create the cumulative log first if it doesn't exist
#  if [ ! -r access_log.${YEAR}.gz ]; then
#     sudo -u ${USER} touch access_log.${YEAR}
#     sudo -u ${USER} gzip access_log.${YEAR}
#  fi
#
#          # Create a backup and fix permissions
#	  if [ ! ${DEBUG} ]; then
#	      sudo -u ${USER} cp access_log.${YEAR}.gz access_log.${DATE}.before_concatenation.bak.gz
#	      chown ${USER} access_log.${DATE}.before_concatenation.bak.gz
#	  fi
#          # Concatenate this month to the cumulative log
#	  if [ ! ${DEBUG} ]; then
#	      sudo -u ${USER} cat access_log.${DATE}.gz >> access_log.${YEAR}.gz
#	      chown ${USER} access_log.${YEAR}.gz
#	  fi

	  sudo chown ${USER} ${PREFIX}-${LOG}.${YEAR}.gz
      done
  done

  ################################################
  # Rsync the stats directory to the stats host
  ################################################

LEAVE_LOCAL=1

  # We won't sync them up.

  if [ ! ${LEAVE_LOCAL} ]; then
      sudo -u ${USER} rsync -avz --exclude=*before_concatenation* --exclude=*.bak ${LOGDIR}/ ${STATS_USER}@${STATS_HOST}:projects/wormbase/log_archive/
           
    # Fire off the analyze_logs_by_month.sh script on a suitable macine
      # TODO: Test and run manually on wb-dev
#      sudo -u ${USER} ssh -t ${STATS_HOST} /home/${STATS_USER}/projects/wormbase/website-admin/log_analysis/analysis_by_month/analyze_logs.sh ${DATE}
      
  # Send myself an announcement
      # TODO: Confirm that emails work
      sudo -u ${USER} echo "TEST FROM WEB1: WormBase Log Analysis for ${DATE} complete. See: http://www.wormbase.org/stats/${DATE}/" | mail -s "WormBase Log Analysis: ${DATE}" toddwharris@gmail.com
      
  fi
fi