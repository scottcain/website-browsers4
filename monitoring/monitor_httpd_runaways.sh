#!/bin/sh

# Kill httpd processes that grow beyond 800MB. Absurd.
# Run this as a cron job every five minutes.

for i in `/bin/ls -d /proc/[0-9]*`; do
        if [ -f $i/stat ]; then
#                pid=`/usr/bin/awk '{ if ($2 == "(httpd)" && $23 > $SIZE) print $1}' $i/stat`
                pid=`/usr/bin/awk '{ if ($2 == "(httpd)" && $23 > 800000000) print $1}' $i/stat`
                if [ "$pid" != "" ]; then
                        echo "Killing $pid because of load average: `awk '{print $1}' /proc/loadavg`"
                        kill -9 $pid
                fi
        fi
done