#!/usr/bin/perl
# Simple log rotation script for nginx

$LOGPATH    = '/usr/local/wormbase/logs';
$MAXCYCLE   = 7;
$GZIP       = '/bin/gzip';

@PREFIXES = qw/www beta nginx blog forum wiki api couchdb cache/;
@LOGS     = qw/access_log error_log cache_log purge_log/;

%ARCHIVE=('www-access_log'     => 1,
	  'www-error_log'      => 1,
	  'www-cache_log'      => 1,
	  'beta-access_log'    => 1,
	  'beta-error_log'     => 1,
	  'beta-cache_log'     => 1,
	  'nginx-access_log'   => 1,
	  'nginx-error_log'    => 1,
	  'blog-access_log'    => 1,
	  'blog-error_log'     => 1,
	  'wiki-access_log'    => 1,
	  'wiki-error_log'     => 1,
	  'forum-access_log'   => 1,
	  'forum-error_log'    => 1,
	  'api-access_log'     => 1,
	  'api-error_log'      => 1,
	  'couchdb-access_log' => 1,
	  'couchdb-error_log'  => 1,
	  'cache-purge_log'    => 1,
);

# Change to the squid log directory
chdir $LOGPATH;

foreach $prefix (@PREFIXES) {
    foreach $log (@LOGS) {
	my $filename = "$prefix-$log";

	next if ($prefix eq 'nginx' && $log eq 'cache_log');
	next unless ($ARCHIVE{"$prefix-$log"});
	
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
		
		
#            # Tell squid to close the current log and open a new one
#            system("$SQUID -k rotate -f ${CONFIG}");
	    } else {
		# Dealing with other log files
		$newname = join(".",$filename,$s+1);
		rename $oldname,$newname if -e $oldname;
	    }
	}
    }
}

system("kill -USR1 `cat /usr/local/wormbase/logs/nginx.pid`");


