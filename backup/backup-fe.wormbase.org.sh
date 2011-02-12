#!/bin/sh

DATE=`date +%m-%d-%Y`
BAK=${DATE}

cd /home/todd
echo "Creating backup directory at /home/todd/${BAK}"
tar -czf ${BAK}.tgz -C /usr/local squid apache website-admin rrdtool-1.2.10 \
                --exclude squid/var \
                -C /home/todd build

scp ${BAK}.tgz brie3.cshl.org:backups/fe/.
rm -rf ${BAK}.tgz
