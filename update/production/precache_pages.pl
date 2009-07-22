#!/usr/bin/perl

# Precache specific WormBase pages
# Use this script to populate the ON DISK (not squid) cache
# That is, it should be run after a release to automatically
# populate the on disk cache of all gene pages
# squid can then pull them from the back end servers as necessary

# Usage: ./precache_pages.pl

use strict;
use Ace;
use WWW::Mechanize;
#use Storable;
$|++;

use constant URL => 'http://www.wormbase.org/db/gene/gene?class=Gene;name=';
my $start = time();

my $previous = shift;
my %previous = parse() if $previous;

#my $db    = Ace->connect(-path=>'/usr/local/acedb/elegans');
my $db    = Ace->connect(-host=>'localhost',-port=>2005);
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans"});
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans" AND CGC_name AND Molecular_name});
my @genes      = $db->fetch(Gene => '*');

my %genes = map { $_ => 1 } @genes;

my $version = $db->status->{database}{version};
open OUT,">$version-precached-pages.txt";

my %status;
foreach  my $id (%genes) {
  $db ||= Ace->connect(-host=>'localhost',-port=>2005);
  my $gene = $db->fetch(Gene=>$id);
#  next if $gene->Species =~ /briggsae/i;
  next if (defined $previous{$gene});
  my $url = URL . $gene;
  sleep 2;
	
	my $cache_start = time();
  # No need to watch state - create a new agent for each gene to keep memory usage low.
  my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
  $mech->get($url);
  my $success = ($mech->success) ? 'success' : 'failed';
	my $cache_stop = time();
  $status{$gene} = $success;
  print OUT join("\t",$gene,$gene->Public_name,$url,$success,$cache_stop - $cache_start),"\n";
}

my $end = time();
my $seconds = $end - $start;
print OUT "\n\nTime required to cache " . (scalar keys %status) . "genes: ";
printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];


sub parse {
  open IN,"$previous";
  my %previous;
  while (<IN>) {
	chomp;
        my ($gene,@junk) = split("\t");
	$previous{$gene}++;
  }
  return %previous;
}
