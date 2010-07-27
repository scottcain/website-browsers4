#!/usr/bin/perl
# A simple log rotation script for squid
# T. Harris, 7/2005

$LOGPATH    = '/usr/local/squid/logs';
$MAXCYCLE   = 7;
$GZIP       = '/usr/bin/gzip';

@LOGNAMES=('access_log');
%ARCHIVE=('access_log'=>1);

$CONFIG = '/usr/local/wormbase/admin/squid/etc/squid3-basic.conf';
$SQUID  = '/usr/sbin/squid';

# Change to the squid log directory
chdir $LOGPATH;

foreach $filename (@LOGNAMES) {
    system "$GZIP -c $filename.$MAXCYCLE >> $filename.gz" 
        if -e "$filename.$MAXCYCLE" and $ARCHIVE{$filename};
    for (my $s=$MAXCYCLE; $s--; $s >= 0 ) {
        $oldname = $s ? "$filename.$s" : $filename;

        # Processing the primary access_log file
	# Need to handle this a bit differently so that squid
        # can continue writing to the log file
        if ($filename eq $oldname) {
            # Rotate the current log file without interrupting the logging process
            system("mv $filename $filename.1");
      
            # Tell squid to close the current log and open a new one
            system("$SQUID -k rotate -f ${CONFIG}");
        } else {
          # Dealing with other log files
          $newname = join(".",$filename,$s+1);
          rename $oldname,$newname if -e $oldname;
        }
    }
}
