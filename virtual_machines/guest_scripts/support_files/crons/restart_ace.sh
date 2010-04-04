#!/bin/sh

# Periodically restart acedb to keep memory under control.

# Use ace.pl to restart ace.
# This command will cause acedb to refuse any new connections
# and shut down once all clients are finished.
/usr/bin/ace.pl -host localhost -port 2005 -login admin -pass ace123 -exec shutdown
rm -rf /usr/local/acedb/elegans/database/readlocks/*

# HOWEVER: clients connecting through the web interface are often
# hung. Because we have already shutdown the database, the website
# is essentially down.  Restarting apache closes all current
# clients allowing acedb to restart.
# Not exactly the best solution as sessions might be
# closed inadvertently on users.
/usr/local/apache/bin/apachectl restart


exit;


# This rather heavy-handed approach causes problems
# with xinetd (binding to port, transport endpoint, etc)
PID=`ps -C sgifaceserver -o pid=`
if [ "$PID" != ""]; 
then

    echo ${PID}
    exit
   kill -9 ${PID}
   # Give adequate time for things to get cleaned up...
   sleep 10
fi
exit
# Restart xinetd for good measure
/etc/rc.d/init.d/xinetd restart

# restart httpd
/usr/local/apache/bin/apachectl restart
