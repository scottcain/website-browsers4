#!/usr/bin/perl
#this is appropriate for a typical redhat system
#will need to be modified for others

$HOSTNAME=`hostname`;
chomp $HOSTNAME;

#$PIDFILE='/etc/httpd/run/httpd.pid';
if ($HOSTNAME eq 'ip-10-196-103-21') {
    $PIDFILE='/var/run/apache2.pid';
} else {
    $PIDFILE = '/usr/local/apache2/logs/httpd.pid';
}

$LOGPATH    = '/usr/local/wormbase/logs';

$MAXCYCLE   = 7;
$GZIP       = '/usr/bin/gzip';

@LOGNAMES =("classic-httpd-access.log","classic-httpd-error.log");
%ARCHIVE  =("classic-httpd-access.log"=>1,
	    "classic-httpd-error.log"=>1);

chdir $LOGPATH;  # Change to the log directory
foreach $filename (@LOGNAMES) {
    system "$GZIP -c $filename.$MAXCYCLE >> $filename.gz" 
        if -e "$filename.$MAXCYCLE" and $ARCHIVE{$filename};
    for (my $s=$MAXCYCLE; $s--; $s >= 0 ) {
        $oldname = $s ? "$filename.$s" : $filename;
        $newname = join(".",$filename,$s+1);
        rename $oldname,$newname if -e $oldname;
    }
}
kill 'HUP',`cat $PIDFILE`;

