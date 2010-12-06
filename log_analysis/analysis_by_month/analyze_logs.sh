#!/bin/bash
#export PERL5LIB="/usr/local/wormbase/website-classic/extlib/lib/perl5:/usr/local/wormbase/website-classic/extlib/lib/perl5/x86_64-linux"


# Analyze logs on a per-release, yearly, and overall basis
# Analog and rmagic need to be run on a system with lots of memory

# This script is automatically called by concatenate_logs_by_month.sh
# when it completes.
# There is no need to run it under cron.

# LATEST_RELEASE should by YYYY.MM
LATEST_RELEASE=$1
#BINDIR=/home/tharris/projects/wormbase/wormbase-admin/log_analysis
BINDIR=/home/todd/Dropbox/Projects/wormbase/wormbase-admin/log_analysis
#LOGDIR=/usr/local/acedb/wormbase_log_archive
#LOGDIR=/home/tharris/projects/wormbase/log_archive
LOGDIR=/home/todd/projects/wormbase/log_archive
SITE=www.wormbase.org
HTMLSTATS=/usr/local/wormbase/website-shared-files/html/stats
ANALOG=${BINDIR}/analog
RMAGIC=${BINDIR}/rmagic
#TARGET=/usr/local/wormbase/website-classic/html/stats

if [ ! ${LATEST_RELEASE} ]; then
  echo "Usage: analyze_logs.sh YYYY.MM"
  exit
fi

YEAR=${LATEST_RELEASE:0:4}

################################
# MOST RECENT RELEASE ANALYSIS
################################

# Have the new logs for the last month been transferred yet?
  
# If so, check to see that the new logs are there,
# If they are, then analyze 'em.
# If not, exit silently.

## Create a directory for this release in /stats

# THIS SHOULDN"T BE RELEASE, just the mohth
mkdir ${HTMLSTATS}/${LATEST_RELEASE}

# Run analog with a non-standard configuration file
# Per-year access stats can be created using the analog.conf file
echo "Running analog for ${RELEASE}..."
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.${LATEST_RELEASE}.gz \
    +C"OUTFILE ${HTMLSTATS}/${LATEST_RELEASE}/access_log-parsed.${LATEST_RELEASE}" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"YEARLY OFF"

#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Now run Report Magic with a non-standard configuration
echo "Running report magic for ${RELEASE}..."
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/${LATEST_RELEASE}/access_log-parsed.${LATEST_RELEASE} \
    -reports_File_Out=${HTMLSTATS}/${LATEST_RELEASE}/ \
    -website_Title="WormBase Access Statistics For ${LATEST_RELEASE}" \
    -website_Webmaster="webmaster@wormbase.org" \
    -website_Base_URL="http://${SITE}/" 


# Run analog with a non-standard configuration file
# Per-year access stats can be created using the analog.conf file
mkdir ${HTMLSTATS}/${LATEST_RELEASE}-nogoogle
echo "Running analog for ${LATEST_RELEASE}, excluding google"
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.${LATEST_RELEASE}.gz \
    +C"OUTFILE ${HTMLSTATS}/${LATEST_RELEASE}-nogoogle/access_log-parsed.${LATEST_RELEASE}" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"HOSTEXCLUDE *googlebot*" \
    +C"YEARLY OFF"

#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Now run Report Magic with a non-standard configuration
echo "Running report magic for ${RELEASE}, excluding google"
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/${LATEST_RELEASE}-nogoogle/access_log-parsed.${LATEST_RELEASE} \
    -reports_File_Out=${HTMLSTATS}/${LATEST_RELEASE}-nogoogle/ \
    -website_Title="WormBase Access Statistics For ${LATEST_RELEASE}" \
    -website_Webmaster="webmaster@wormbase.org" \
    -website_Base_URL="http://${SITE}/" 


# Calculate the most popular genes
#/usr/local/wormbase/util/log_analysis/most_popular_genes.pl \
#-logs /usr/local/wormbase/logs/archive/with_hosts/access_log.${LATEST_RELEASE}.gz \
#-output /usr/local/wormbase/html/stats/${LATEST_RELEASE}/ \
#-release ${LATEST_RELEASE} \
#-format HTML


################################
# YEAR-TO-DATE ANALYSIS
################################
# Create a year-to-date directory if it doesn't already exist.
mkdir ${HTMLSTATS}/${YEAR}

# Calculate wormbase stats
#${BINDIR}/wormbase_stats.pl \
#    ${LOGDIR}/with_hosts/access_log.${YEAR}.gz \ 
#    ${HTMLSTATS}/${YEAR}/host_stats.txt
#
# Tally hosts
#${BINDIR}/tally_hosts.pl ${HTMLSTATS}/${YEAR}/host_stats.txt > ${HTMLSTATS}/${YEAR}/domains.txt
#
# Tally referrers
#${BINDIR}/tally_referers.pl ${HTMLSTATS}/${YEAR}/host_stats.txt > ${HTMLSTATS}/${YEAR}/referers.txt

# analog
echo "Running analog for ${YEAR} to-date..."
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.01-06.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.07-12.gz \
    +C"OUTFILE ${HTMLSTATS}/${YEAR}/access_log-parsed.${YEAR}" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"YEARLY OFF"

#    ${LOGDIR}/with_hosts/access_log.${YEAR}.gz \
#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Report magic
echo "Running report magic for ${YEAR} to-date..."
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/${YEAR}/access_log-parsed.${YEAR} \
    -reports_File_Out=${HTMLSTATS}/${YEAR}/ \
    -website_Base_URL="http://${SITE}" -website_Title="WormBase Access Statistics: ${YEAR}-to-date" 

exit

# Repeat, this time excluding google
mkdir ${HTMLSTATS}/${YEAR}-nogoogle
echo "Running analog for ${YEAR} to-date, excluding googlebot..."
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.01-06.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.07-12.gz \
    +C"OUTFILE ${HTMLSTATS}/${YEAR}-nogoogle/access_log-parsed.${YEAR}" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"HOSTEXCLUDE *googlebot*" \
    +C"YEARLY OFF"

#    ${LOGDIR}/with_hosts/access_log.${YEAR}.gz \

#    +C"REFEXCLUDE http://${SITE}/" \
#    +C"REFSITEEXCLUDE http://${SITE}/" \
#    +C"REFEXCLUDE *wormbase*" \
#    +C"REFSITEEXCLUDE http://wormbase.org/" \
#    +C"REFSITEEXCLUDE http://brie3.cshl.org/" \
#    +C"REFEXCLUDE http://brie3.cshl.org/" 

# Report magic
echo "Running report magic for ${YEAR} to-date, excluding googlebot..."
${RMAGIC}/rmagic.pl ${BINDIR}/rmagic.conf \
    -statistics_File_In=${HTMLSTATS}/${YEAR}-nogoogle/access_log-parsed.${YEAR} \
    -reports_File_Out=${HTMLSTATS}/${YEAR}-nogoogle/ \
    -website_Base_URL="http://${SITE}" -website_Title="WormBase Access Statistics: ${YEAR}-to-date" 


################################
# OVERALL ANALYSIS
################################
# This should include all files in /with_hosts
# analog
echo "Running analog for all years..."
mkdir ${HTMLSTATS}/total
${ANALOG}/analog -G +g${BINDIR}/analog.conf \
    ${LOGDIR}/with_hosts/access_log.2001.gz \
    ${LOGDIR}/with_hosts/access_log.2002.gz \
    ${LOGDIR}/with_hosts/access_log.2003.gz \
    ${LOGDIR}/with_hosts/access_log.2004.gz \
    ${LOGDIR}/with_hosts/access_log.2005.gz \
    ${LOGDIR}/with_hosts/access_log.2006.gz \
    ${LOGDIR}/with_hosts/access_log.2007.gz \
    ${LOGDIR}/with_hosts/access_log.2008.gz \
    ${LOGDIR}/with_hosts/access_log.2009.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.01-06.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.07-12.gz \

    +C"OUTFILE ${HTMLSTATS}/total/access_log-parsed" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"YEARLY ON"

#    ${LOGDIR}/with_hosts/access_log.2010.gz \

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
    ${LOGDIR}/with_hosts/access_log.2009.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.01-06.gz \
    ${LOGDIR}/with_hosts/access_log.${YEAR}.07-12.gz \
    +C"OUTFILE ${HTMLSTATS}/total-nogoogle/access_log-parsed" \
    +C"HOSTNAME ${SITE}" \
    +C"HOSTURL http://${SITE}/" \
    +C"HOSTEXCLUDE *googlebot*" \
    +C"YEARLY ON"

#    ${LOGDIR}/with_hosts/access_log.2010.gz \
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



# Sync to the appropriate staging directories
rsync -Cav /usr/local/wormbase/website-shared-files/html/stats \
    /usr/local/wormbase/website-classic-staging/html
