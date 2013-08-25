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

if ($format eq 'record') {
    # no header
} else {
    print join("\t",qq/gene_id public_name molecular_name concise_description provisional_description detailed_description gene_class_description/),"\n";
}
my $i = $dbh->fetch_many(-query=>qq{find Gene Species=$g*$species_alone});
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
    my $gene_class = $gene->Gene_class;
    my $gene_class_description = $gene_class ? $gene_class->Description : 'not known';
    if ($format eq 'record') {
	print join("\t",$gene,$name,$molecular_name) . "\n";
	print rewrap("Concise description: $concise\n");
	#  print rewrap("Brief description: $brief\n");
	print rewrap("Provisional description: $prov\n");
	print rewrap("Detailed description: $detailed\n");
	print rewrap("Gene class description: $gene_class_description\n");
	print $separator;
    } else {
	print join("\t",$gene,$name,$molecular_name,$concise,$prov,$detailed,$gene_class_description),"\n";
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
