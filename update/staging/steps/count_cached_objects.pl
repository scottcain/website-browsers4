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
    
    my $actual = `sort -u -k1,2 $class.txt | wc -l`;
    chomp $actual;

    print <<END;
$class
expected: $expected
END
;

    # Get stats for the current class.
    if ( -e "$class.txt" && -s "$class.txt") {
	my $row = `tail -1 $class.txt`;
	chomp $row;
	my @fields = split("\t",$row);
	my $id = $fields[1];
	my $found = `egrep -n $id $class.ace`;
	$found =~ /(.*):.*/;
	my $current_object = $1;
	
    print <<END;
complete: $actual
Currently on $current_object out of $expected
--
END
;
    } else {
	print <<END;
Not yet processed
--
END
;
    }
}
