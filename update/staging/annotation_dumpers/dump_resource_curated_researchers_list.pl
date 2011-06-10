#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use Getopt::Long;
use Ace;
use strict;

my ($path,$host,$port,$species);
GetOptions(
           "path=s"      => \$path,
	   "host=s"      => \$host,
	   "port=i"      => \$port,
           "species=s"   => \$species,
	  );

$path || die <<USAGE;

Usage: $0 [options]
   
   --path  Path to acedb database
   OR
   --host      hostname for acedb server
   --port      port number (for specified host)

USAGE
    ;


# Establish a connection to the database.
my $dbh = $path
    ? Ace->connect(-path => $path )
    : Ace->connect(-port => $port, -host => $host) or die $!;


my @people = $dbh->fetch(Person => '*');
foreach (@people) {
    my @tags = $_->col;
    my @email;
    my $lab = $_->Laboratory;
    foreach my $tag (@tags) {
	next unless $tag eq 'Address';
	my @entries = $tag->col;
	foreach my $entry (@entries) {
	    next unless $entry eq 'Email';
	    @email = $entry->right;
	}
    }
    print join("\t",$_,$_->Standard_name,$_->Laboratory,join(", ",@email)) . "\n";
}
