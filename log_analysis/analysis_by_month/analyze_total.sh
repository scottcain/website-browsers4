#!/bin/sh

# Analyze logs on a per-release, yearly, and overall basis
# Analog and rmagic need to be run on a system with lots of memory

# This script is automatically called by concatenate_logs_by_month.sh
# when it completes.
# There is no need to run it under cron.

# LATEST_RELEASE should by YYYY.MM
LATEST_RELEASE=$1
BINDIR=/home/todd/projects/wormbase/admin/log_analysis
#LOGDIR=/usr/local/acedb/wormbase_log_archive
LOGDIR=/home/todd/projects/wormbase/log_archive
SITE=www.wormbase.org
HTMLSTATS=/usr/local/wormbase/html/stats
ANALOG=${BINDIR}/analog
RMAGIC=${BINDIR}/rmagic
TARGET=/usr/local/wormbase/html/stats

if [ ! ${LATEST_RELEASE} ]; then
  echo "Usage: analyze_logs.sh YYYY.MM"
  exit
fi

YEAR=${LATEST_RELEASE:0:4}
echo $YEAR

################################
# OVERALL ANALYSIS
################################
# This should include all files in /with_hosts
# analog
echo "Running analog for all years..."
mkdir ${HTMLSTATS}/total
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
#    ${LOGDIR}/with_hosts/access_log.2001.gz \
#    ${LOGDIR}/with_hosts/access_log.2002.gz \
#    ${LOGDIR}/with_hosts/access_log.2003.gz \
#    ${LOGDIR}/with_hosts/access_log.2004.gz \
#    ${LOGDIR}/with_hosts/access_log.2005.gz \
#    ${LOGDIR}/with_hosts/access_log.2006.gz \
#    ${LOGDIR}/with_hosts/access_log.2007.gz \
#    ${LOGDIR}/with_hosts/access_log.2008.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.gz \
    +C"OUTFILE ${HTMLSTATS}/total/access_log-parsed" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"YEARLY ON"

#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Report magic
echo "Running report magic for all years..."
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/total/access_log-parsed \
    -reports_File_Out=${HTMLSTATS}/total/ \
    -website_Base_URL="http://${SITE}" -website_Title="WormBase Access Statistics: Total Stats" 

# Repeat, this time excluding google
mkdir ${HTMLSTATS}/total-nogoogle
echo "Running analog for all years, excluding googlebot..."
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.2001.gz \
    ${LOGDIR}/with_hosts/access_log.2002.gz \
    ${LOGDIR}/with_hosts/access_log.2003.gz \
    ${LOGDIR}/with_hosts/access_log.2004.gz \
    ${LOGDIR}/with_hosts/access_log.2005.gz \
    ${LOGDIR}/with_hosts/access_log.2006.gz \
    ${LOGDIR}/with_hosts/access_log.2007.gz \
    ${LOGDIR}/with_hosts/access_log.2008.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.gz \
    +C"OUTFILE ${HTMLSTATS}/total-nogoogle/access_log-parsed" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"HOSTEXCLUDE *googlebot*" \
    +C"YEARLY ON"

#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Report magic
echo "Running report magic for all years, excluding googlebot..."
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/total-nogoogle/access_log-parsed \
    -reports_File_Out=${HTMLSTATS}/total-nogoogle/ \
    -website_Base_URL="http://${SITE}" -website_Title="WormBase Access Statistics: Total Stats" 


# Here is an example of analyzing a single year
#/home/todd/lib/analog-5.32/analog -G +g/usr/local/wormbase/util/log_analysis/analog.conf \
#    /usr/local/wormbase/logs/archive/with_hosts/access_log.2004.gz \
#    +C"OUTFILE /usr/local/wormbase/html/stats/2004/access_log-parsed.2004" \
#    +C"HOSTNAME www.wormbase.org" \
#    +C"HOSTURL http://www.wormbase.org/" \
#    +C"REFEXCLUDE http://www.wormbase.org/" \
#    +C"REFSITEEXCLUDE http://www.wormbase.org/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Report magic
#/home/todd/lib/rmagic/rmagic.pl /usr/local/wormbase/util/log_analysis/rmagic.conf \
#    -statistics_File_In=/usr/local/wormbase/html/stats/2004/access_log-parsed.2004 \
#    -reports_File_Out=/usr/local/wormbase/html/stats/2004/ \
#    -website_Base_URL="http://www.wormbase.org" -website_Title="WormBase Access Statistics: 2004" 
