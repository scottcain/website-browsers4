#!/usr/bin/perl
# Simple log rotation script for nginx

my $logroot   = '/usr/local/wormbase/logs';
my $maxcycle  = 7;
my $gzip      = '/bin/gzip';
my @logs      = qw/access_log error_log cache_log/;

opendir (DIR, $logroot) or die $!;
while (my $logdir = readdir(DIR)) {
    next if ($logdir =~ m/^\./);
    
    # A file test to check that it is a directory    
    next unless (-d "$logroot/$logdir");
    
    chdir "$logroot/$logdir";
    
    foreach my $filename (@logs) {
	# Not all hosts have the cache log.
	next unless -e "$logroot/$logdir/$filename";
	
	system "$gzip -c $filename.$maxcycle >> $filename.gz" 
	    if -e "$filename.$maxcycle";# and $ARCHIVE{$filename};
	for (my $s=$maxcycle; $s--; $s >= 0 ) {
	    $oldname = $s ? "$filename.$s" : $filename;
	    	    
	    # This is the first entry, eg access_log -> access_log.1
	    if ($filename eq $oldname) {
		system("mv $filename $filename.1");
		# print "NEW FILENAME IS SAME AS OLD $filename\n";	       
	    } else {
		# Dealing with other log files
		$newname = join(".",$filename,$s+1);
		rename $oldname,$newname if -e $oldname;
		print "FILENAME IS NOT SAME AS OLD $filename; renaming $logdir/$oldname to $newname\n";
	    }
	}
    }
}

system("kill -USR1 `cat /usr/local/wormbase/logs/nginx.pid`");


