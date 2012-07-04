#!/usr/bin/perl

use strict;
my $version = shift;

chdir("/usr/local/wormbase/databases/$version/cache/logs");

my @classes = glob("*\.ace");
foreach (@classes) {
    next if $_ =~ /dump/; 
    $_ =~ /(.*).ace/;
    my $class = $1;
    my $expected = `wc -l $class.ace` - 5;  # three extra rows in ace files.
    chomp $expected;
    
    my ($status,$actual);
    # Get stats for the current class.
    if ( -e "$class.log" && -s "$class.log") {

	$actual = `sort -u -k1,2 $class.log | wc -l`;
	chomp $actual;
	
	my $row = `tail -1 $class.log`;
	chomp $row;
	my @fields = split("\t",$row);
	my $id = $fields[1];
	my $found = `egrep -n $id $class.ace`;
	$found =~ /(.*):.*/;
	my $current_object = $1;

	if ($actual == $expected) {
	    $status = 'COMPLETE';
	} else {	    
	    $status = ($expected - $actual) . " objects remaining to process or broken";
	}
    } else {
	$status = "NOT YET PROCESSED";
    }
    $actual ||= 0;
    print "$class\n";
    print "\tstatus  : $status\n";
    print "\texpected: $expected\n";
    print "\tcomplete: $actual\n";   
}
