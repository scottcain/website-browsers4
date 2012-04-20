#!/usr/bin/perl

use strict;
my $version = shift;

chdir("/usr/local/wormbase/databases/$version/cache/logs");

my @classes = glob("*object_list.txt");
foreach (@classes) {
    $_ =~ /$version-(.*)-object_list.txt/;
    my $class = $1;
    my $expected = `wc -l $class-object_list.txt`;
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
