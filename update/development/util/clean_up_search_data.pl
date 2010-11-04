#!/usr/bin/perl

use strict;


my $release = $ARGV[0];

my $datadir ="/usr/local/wormbase/databases/$release/ontology";

my $original_file = "search_data_preprocessed.txt";
my $out_file = "search_data.txt";

open IN, "< $datadir/$original_file"  or die "Can't open in file\n";
open OUT, "> $datadir/$out_file" or die "Can't open out file\n";

foreach my $line (<IN>) {

	chomp $line;
	my @line_elements = split /\|/, $line;
	$line_elements[1] =~ s/\_/ /g;
	$line_elements[4] =~ s/\_/ /g;
	
	my $new_line = join "|", @line_elements;
	
	print OUT "$new_line\n";

}

exit;
