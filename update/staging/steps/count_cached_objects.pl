#!/usr/bin/perl

use strict;
my $version = shift;

chdir("/usr/local/wormbase/databases/$version/cache/logs");

my @classes = glob("*ace");
foreach (@classes) {
    $_ =~ /(.*).ace/;
    my $class = $1;
    my $expected = `wc -l $class.ace`;
    chomp $expected;
    
    my $actual = `sort -u -k1,2 $class.txt | wc -l`;
    chomp $actual;
    
    print <<END;
$class
expected: $expected
complete: $actual
--
END
;
}
