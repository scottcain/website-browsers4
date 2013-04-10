#!/usr/bin/env perl

use strict;
use IO::File;
use Ace;

my $format = shift;
$format ||= 'XML';

my $db = Ace->connect(-host=>'localhost',-port=>2005);

my @classes = $db->classes;


foreach my $class (@classes) {
    
    system("mkdir -p out/$lcass");
    my $i = $db−>fetch_many($class => ’*’);  # fetch a cursor
    my $fh = new IO::File;
    while ($obj = $i−>next) {
	if ($fh->open(">out/$class/$obj.xmml")) {
	    if ($format eq 'XML') {
		print $fh $obj−>asXML;
	    } else {
	    }
	    $fh->close;
	}
    }
}
