#!/bin/bash

# Periodically restart sgifaceserver and apache.
# It would be far, far better to do this either
# checking memory use or by polling the
# site/sgifaceserver and restarting if unresponsive.

chown root /usr/local/wormbase/acedb/wormbase/database/serverlog.wrm
echo ' ' > /usr/local/wormbase/acedb/wormbase/database/serverlog.wrm

# ensure that acedb owns the logs - there is some other log rotation
# functionality that periodically sets the owner to root.
chown acedb:acedb /usr/local/wormbase/acedb/wormbase/database/serverlog.wrm
chown acedb:acedb /usr/local/wormbase/acedb/wormbase/database/log.wrm
sudo killall -9 sgifaceserver
#sleep 5
#/etc/init.d/xinetd restart
sudo /usr/local/apache2/bin/apachectl graceful
