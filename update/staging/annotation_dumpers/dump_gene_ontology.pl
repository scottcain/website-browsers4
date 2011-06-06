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

$path || die <<USAGE;

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


# Only for C. elegans now.
exit 0 unless $species =~ /elegans/;

my @genes = $DB->fetch(-class=>'Gene',-name=>'*');


print "# WormBase, version " . $dbh->version;
print "# Generated $date\n";
print join('/','#WBGene ID','Public Name','Molecular Name','Institute','Email'),"\n";

foreach (@genes) {
    next unless ($_->Species eq 'Caenorhabditis elegans');
    next if ($_->Method eq 'history');

    my @cols;

    push @cols, $_,$_->Public_name,$_->Molecular_name,
    my @go = $_->GO_term;
    next unless @go;
    
    # Consolidate all the GO terms by their type
    my $types = {};
    foreach (@go) {
	my $term = $_->Term;
	my $type = $_->Type;
	push (@{$types->{$type}},"$term ($_)");
    }
    
    foreach my $type (qw/Molecular_function Cellular_component Biological_process/) {
	foreach (sort { $a cmp $b } @{$types->{$type}}) {
	    print "\t$type: $_\n";
	}
    }
}
