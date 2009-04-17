#!/usr/bin/perl

use Ace;
use strict;

my $db = Ace->connect(-host=>'localhost',-port=>2005);

my @people = $db->fetch(Person => '*');
foreach (@people) {
    my @tags = $_->col;
    my @email;
    foreach my $tag (@tags) {
	next unless $tag eq 'Address';
	my @entries = $tag->col;
	foreach my $entry (@entries) {
	    next unless $entry eq 'Email';
	    @email = $entry->right;
	}
    }
    print $_->Full_name . ': ' .join(", ",@email) . "\n";
}
