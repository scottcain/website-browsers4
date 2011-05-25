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

my $emacs = $ENV{EMACS};
my $delim = $emacs ? "\n" : "\r";
my $count;

my $separator = "=\n";
$no_entry  ||= "none available";
$format    ||= 'record';

my ($g,$species_alone) = split("_",$species);
$g = uc($g);

my $i = $dbh->fetch_many(-query=>qq{find Gene where Species=$g*$species_alone});
while (my $gene = $i->next) {
    next unless $gene->Species =~ /$species_alone/;
    my $name = $gene->Public_name || 'not known';
    my $molecular_name = $gene->Molecular_name || 'not known';
    next unless $gene->Species eq 'Caenorhabditis elegans';
    
    # Fetch each and any of the possible brief identifications
    my $concise  = $gene->Concise_description     || $no_entry;
#  my $brief    = $gene->Brief_description       || $no_entry;
    my $prov     = $gene->Provisional_description || $no_entry;
    my $detailed = $gene->Detailed_description    || $no_entry;
#  print "$gene" . ($name ? " ($name)\n" : "\n");
    if ($format eq 'record') {
	print join("\t",$gene,$name,$molecular_name);
	print rewrap("Concise description: $concise\n");
	#  print rewrap("Brief description: $brief\n");
	print rewrap("Provisional description: $prov\n");
	print rewrap("Detailed description: $detailed\n");
	print $separator;
    } else {
	print join("\t",$gene,$name,$molecular_name,$concise,$prov,$detailed),"\n";
    }
}



sub rewrap {
    my $text = shift;
    $text =~ s/^\n+//gs;
    $text =~ s/\n+$//gs;
    my @words = split(/\s/,$text);
    my ($para,$line);
    foreach (@words) {
	$line .= "$_ ";
	next if length ($line) < 80;
	$para .= "$line\n";
	$line = undef;
    }
    $para .= "$line\n" if ($line);
    return $para;
}
