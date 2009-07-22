#!/usr/bin/perl
#this is appropriate for a typical redhat system
#will need to be modified for others

$LOGPATH    = '/usr/local/wormbase/logs';
$PIDFILE    = '/var/run/apache2.pid';
$MAXCYCLE   = 7;
$GZIP       = '/usr/bin/gzip';

@LOGNAMES=('classic-access_log','classic-error_log');
%ARCHIVE=('classic-access_log'=>1,'classic-error_log'=>1);

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

