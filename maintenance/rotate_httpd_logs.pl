#!/usr/bin/perl
#this is appropriate for a typical redhat system
#will need to be modified for others

$HOSTNAME=`hostname`;
chomp $HOSTNAME;

#$PIDFILE='/etc/httpd/run/httpd.pid';
#if ($HOSTNAME =~ /wb\-dev/) {
#    $PIDFILE='/var/run/apache2.pid';
#} else {
    $PIDFILE = '/usr/local/apache2/logs/httpd.pid';
#}

$LOGPATH    = '/usr/local/wormbase/logs';

$MAXCYCLE   = 7;
$GZIP       = '/usr/bin/gzip';

@LOGNAMES=("classic-access_log-$HOSTNAME","classic-error_log-$HOSTNAME");
%ARCHIVE=("classic-access_log-$HOSTNAME"=>1,"classic-error_log-$HOSTNAME"=>1);

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

