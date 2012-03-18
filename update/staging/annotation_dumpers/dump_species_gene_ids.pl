#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use Getopt::Long;
use Ace;
use strict;

my ($path,$host,$port,$species,$no_entry,$format);
GetOptions(
           "path=s"      => \$path,
	   "host=s"      => \$host,
	   "port=i"      => \$port,
           "species=s"   => \$species,
	   "no_entry=s"  => \$no_entry,
	   "format=s"    => \$format,
	  );

($path || ($host && $port)) || die <<USAGE;

Usage: $0 [options]
   
   --path  Path to acedb database
   OR
   --host      hostname for acedb server
   --port      port number (for specified host)

  Optional:
   --species    The species to constrain the dump
   --no_entry  message to display if entry is empty
                      (defaults to "none available")
   --format    record || tab (defaults to tab)

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
$no_entry  ||= "none available";
$format    ||= 'record';

my ($g,$species_alone) = split("_",$species);
$g = uc($g);


# These really only exist for elegans at the moment.
exit 0 unless $species =~ /elegans/;

print "# $g. $species_alone functional descriptions\n";
print "# WormBase version: " . $dbh->version . "\n";
print "# Generated: $date\n";

my $i = $dbh->fetch_many(-query=>qq{find Gene Species=$g*$species_alone});
while (my $gene = $i->next) {
    next unless $gene->Species =~ /$species_alone/;
    my $name = $gene->Public_name;
    my $molecular_name = $gene->Molecular_name;

#    next unless $gene->Species eq 'Caenorhabditis elegans';

    $name = '' if $molecular_name eq $name;  # No need to duplicate
    my $species     = $gene->Species;
    my $taxonomy_id = $species->NCBITaxonomyID;
    
    print join("\t",$taxonomy_id,$gene,$name,$molecular_name),"\n";
}




