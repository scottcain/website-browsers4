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
my %class2url = ( gene => 'http://dev.wormbase.org/db/gene/gene?class=Gene;name=',
		  variation => 'http://dev.wormbase.org/db/gene/variation?class=Variation;name=',
		  protein   => 'http://dev.wormbase.org/db/seq/protein?class=Protein;name=',);

#use constant CACHE_ROOT => '/usr/local/wormbase/website/classic/html/cache';
use constant CACHE_ROOT => '/usr/local/wormbase/databases';


my $start = time();

my $db    = Ace->connect(-host=>'localhost',-port=>2005);
my $version = $db->status->{database}{version};

my @classes = qw/gene protein variation/;
#my @classes = qw/protein variation/;


foreach my $class (@classes) {
    my $cache = CACHE_ROOT . "/$version/cache/$class";
    system("mkdir -p $cache");
    
    my $previous = shift;
    my %previous = parse($cache); # if $previous;
        
    open OUT,">>$cache/$version-precached-pages.txt";
    
    my %status;
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans"});
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans" AND CGC_name AND Molecular_name});

#    my $query_class = ucfirst($class);
#my $i     = $db->fetch_many(-query=>qq{find $query_class Species="Caenorhabditis elegans"});

    my $i = $db->fetch_many(ucfirst($class),'*');
    while (my $obj = $i->next) {
	next if $class eq 'protein' && $obj->name != /^WP:/;
	next unless $obj->Species eq 'Caenorhabditis elegans';
	
	$db ||= Ace->connect(-host=>'localhost',-port=>2005);
	
	
	if ($previous{$obj}) {
	    print STDERR "Already seen $class $obj. Skipping...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	    next;
	}
	
	print STDERR "Fetching and caching $obj\n";
	print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	my $url = $class2url{$class} . $obj;
	sleep 2;
	
	my $cache_start = time();
	# No need to watch state - create a new agent for each gene to keep memory usage low.
	my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
	$mech->get($url);
	my $success = ($mech->success) ? 'success' : 'failed';
	my $cache_stop = time();
	$status{$obj} = $success;
	
	if ($mech->success) {
	    open CACHE,">$cache/$obj.html";
	    print CACHE $mech->content;
	    close CACHE;
	}
	
	print OUT join("\t"
		       ,$obj
		       ,$class eq 'gene' ? $obj->Public_name : ''
		       ,$url
		       ,$success
		       ,$cache_stop - $cache_start)
	    ,"\n";
    }
    
    my $end = time();
    my $seconds = $end - $start;
    print OUT "\n\nTime required to cache " . (scalar keys %status) . "objects: ";
    printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];
}

sub parse {
    my $cache = shift;
#    open IN,"$previous";
#    return unless (-e "$cache/$version-precached-pages.txt");
    if (-e "$cache/$version-precached-pages.txt") {
	open IN,"$cache/$version-precached-pages.txt" or die "$!";
	my %previous;
	while (<IN>) {
	    chomp;
	    my ($obj,$name,$url,$status,$cache_stop) = split("\t");
	    $previous{$obj}++ unless $status eq 'failed';
	    print STDERR "Recording $obj as seen...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
	close IN;
	return %previous;
    }
}
