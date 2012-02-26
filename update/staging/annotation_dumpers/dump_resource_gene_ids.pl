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
	  );

($path || ($host && $port)) || die <<USAGE;

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

my $date = `date +%Y-%m-%d`;
chomp $date;

my $emacs = $ENV{EMACS};
my $delim = $emacs ? "\n" : "\r";
my $count;

my $separator = "=\n";

my ($g,$species_alone) = split("_",$species);
$g = uc($g);


print "# WormBase Gene identifiers\n";
print "# WormBase version: " . $dbh->version . "\n";
print "# NCBI Taxonomy ID \t Species \t GeneID \t Public \t (Locus name) \t Sequence ID\n";
print "# Generated: $date\n";

my $i = $dbh->fetch_many(-query=>qq{find Gene});
while (my $gene = $i->next) {
    my $name = $gene->Public_name;
    my $molecular_name = $gene->Molecular_name;

#    next unless $gene->Species eq 'Caenorhabditis elegans';

    $name = '' if $molecular_name eq $name;  # No need to duplicate
    my $species     = $gene->Species;
    next unless ($species);

    my $taxonomy_id = $species->NCBITaxonomyID;
    next unless ($taxonomy_id);

    print join("\t",$taxonomy_id,$species,$gene,$name,$molecular_name),"\n";
}




