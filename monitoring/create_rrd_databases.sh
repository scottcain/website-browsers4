#!/bin/sh

# This script will create 3 RRD databases that monitor apache,
# sgifaceserver, and mysql every 120 seconds.  If no information is
# available in that time, an "*UNKNOWN*" will be entered into the
# database.

# Minimum value is 0; maximum value is unlimited.
# Entries:
# Process info
# memory: rss
# memory: vsize

# The RRA defines the storage of archived data. IÕm taking the average
# and the last two values define the storage timeframe. I will average
# the values over fifteen-minute time periods (7.5 * 120 seconds = 15
# minutes) and collect the data for a total of 60 days (7.5 * 120 * 5760
# = 60 days).

ROOT=/usr/local/wormbase-admin/monitoring/snmp_monitoring/rrd_databases

for host [ brie3 brie6 vab aceserver blast crestone ] ;
do

  for ps [ apache mysql sgifaceserver ] ;
  do

    rrdtool create ${ROOT}/${host}-${ps}.rrd --start N --step 120 \
    DS:proc:GAUGE:300:0:U DS:rss:GAUGE:300:0:U DS:vsize:COUNTER:300:0:U \
    RRA:AVERAGE:0.5:7.5:5760
    ;
    done
;
done


#rrdtool create ${ROOT}/${HOSTNAME}-mysql.rrd --start N --step 120 \
#DS:proc:GAUGE:300:0:U DS:rss:GAUGE:300:0:U DS:vsize:COUNTER:300:0:U \
#RRA:AVERAGE:0.5:7.5:5760

#rrdtool create ${ROOT}/${HOSTNAME}-sgifaceserver.rrd --start N --step 120 \
#DS:proc:GAUGE:300:0:U DS:rss:GAUGE:300:0:U DS:vsize:COUNTER:300:0:U \
#RRA:AVERAGE:0.5:7.5:5760