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

use constant URL => 'http://dev.wormbase.org/db/gene/gene?class=Gene;name=';
use constant CACHE_ROOT => '/usr/local/wormbase/website/classic/html/cache';


my $start = time();

my $db    = Ace->connect(-host=>'localhost',-port=>2005);
my $version = $db->status->{database}{version};
my $cache = CACHE_ROOT . "/$version/gene";
system("mkdir -p $cache");

my $previous = shift;
my %previous = parse(); # if $previous;

#my $db    = Ace->connect(-path=>'/usr/local/acedb/elegans');
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans"});
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans" AND CGC_name AND Molecular_name});


open OUT,">>$cache/$version-precached-pages.txt";

my %status;
my $i = $db->fetch_many('Gene','*');


while (my $gene = $i->next) {
    
    $db ||= Ace->connect(-host=>'localhost',-port=>2005);


    if ($previous{$gene}) {
	print STDERR "Already seen gene $gene. Skipping...\n";
	next;
    }

    print STDERR "Fetching and caching $gene\n";
    my $url = URL . $gene;
    sleep 2;
    
    my $cache_start = time();
    # No need to watch state - create a new agent for each gene to keep memory usage low.
    my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
    $mech->get($url);
    my $success = ($mech->success) ? 'success' : 'failed';
    my $cache_stop = time();
    $status{$gene} = $success;
    
    if ($mech->success) {
	open CACHE,">$cache/$gene.html";
	print CACHE $mech->content;
	close CACHE;
    }
    
    print OUT join("\t",$gene,$gene->Public_name || '',$url,$success,$cache_stop - $cache_start),"\n";
}

my $end = time();
my $seconds = $end - $start;
print OUT "\n\nTime required to cache " . (scalar keys %status) . "genes: ";
printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];


sub parse {
#    open IN,"$previous";
#    return unless (-e "$cache/$version-precached-pages.txt");
    open IN,"$cache/$version-precached-pages.txt" or die "$!";
    my %previous;
    while (<IN>) {
	chomp;
        my ($gene,$name,$url,$status,$cache_stop) = split("\t");
	$previous{$gene}++ unless $status eq 'failed';
	print STDERR "Recording $gene as seen...\n";
    }
    close IN;
    return %previous;
}
