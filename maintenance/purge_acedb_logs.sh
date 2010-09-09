#!/bin/bash

echo ' ' > /usr/local/wormbase/acedb/wormbase/database/serverlog.wrm

# ensure that acedb owns the logs - there is some other log rotation
# functionality that periodically sets the owner to root.
chown acedb:acedb /usr/local/wormbase/acedb/wormbase/database/serverlog.wrm
chown acedb:acedb /usr/local/wormbase/acedb/wormbase/database/log.wrm
sudo killall -9 sgifaceserver
sleep 5
/etc/init.d/xinetd restart
sudo /usr/local/apache2/bin/apachectl restart
