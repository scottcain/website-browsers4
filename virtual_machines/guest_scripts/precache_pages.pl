#!/usr/bin/perl

# Precache a huge number of pages on the freeze site virtual machines.
# Never any need to generate them ever again!

# This script is designed to be run on localhost since it needs to
# draw objects from the correct database.

# Question: What are the ramifications of use CGI::Cache to cache and
# index such a huge number of pages?  Under a high-load production
# environment, anecdotally, we saw httpd processes start to spend a
# lot of time in "D" seek state as we made the available cache larger.

use strict;
use WWW::Mechanize;
use Time::HiRes qw/tv_interval gettimeofday/;
use Ace;

use constant URL => 'http://localhost/db/get?name=%s;class=%s';

my $start = time();

# Note that the cache is PAGE based, whereas these are individual classes
# Some pages handle multiple classes (and they've morphed over time, too)

# For some of the VMX, I expanded which classes are cached.  For the rest, 
# I got bored and just went with those that are already set to be cached.
my %classes = (
	       WS100 => [ qw/
			     Allele
			     Author
			     Cell
			     Expr_pattern
			     Laboratory
			     Locus
			     Operon
			     PCR_product
			     Protein
			     RNAi
			     Rearrangement
			     Sequence
			     Strain
			     Transcript
			     Transgene
			     /],

	       WS110 => [ ],

	       # WS120 is the first freeze with the CDS class (introduced in WS116)
	       WS120 => [ ],

	       # WS130 is the first freeze with the Gene class (introduced in WS126)
	       WS130 => [ qw/
			     CDS
			     Gene
			     Locus
			     Protein
			     Rearrangement
			     Sequence
			     Strain	
			     Transcript
			     Transgene
			     /],
	       
	       WS140 => [ qw/
			     CDS
			     Gene
			     Gene_class
			     Locus
			     Protein
			     Rearrangement
			     Sequence
			     Strain	
			     Transcript
			     Transgene
			     /],
	       
	       WS150 => [ qw/
			     Author
			     CDS
			     Expression_cluster
			     Gene
			     Gene_class
			     Laboratory
			     Locus
			     Person
			     Person_name
			     Phenotype
			     Protein
			     Rearrangement
			     Sequence
			     Strain	
			     Transcript
			     /],
	       
	       # In later releases, it isn't necessary
	       # to precache objects which are all directed
	       # to the same page.  This is particularly
	       # true of the gene page which redirects all requests
	       # to the appropriate WBGeneID to enhance the
	       # efficiency of caching.
	       WS160 => [ qw/
			     Antibody
			     Cell
			     Expr_pattern
			     Gene
			     Gene_regulation
			     Homology_group
			     Laboratory
			     Motif
			     Operon
			     PCR_product
			     Protein
			     RNAi
			     Rearrangement
			     Sequence
			     Strain
			     Structure_data
			     Transgene
			     Variation
			     /],
	       WS170 => [ qw/ Gene /]
	      );


my $path = shift;
my $db = $path
  ? Ace->connect(-path => $path)
  : Ace->connect(-host => 'localhost',-port => 2005);

$db or die "Couldn't connect to the database at " . ($path ? $path : 'localhost:2005');

my $version = $db->version;
print STDERR "Precaching pages for $version...\n";

my @classes = @{$classes{$version}};
my $count;
foreach my $class (@classes) {
  my $iterator = $db->fetch_many($class => '*');
  print STDERR "Caching $class...\n";
  print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";

  while (my $object = $iterator->next) {
    my $url = sprintf(URL,$object,$class);
    sleep 8;
    # Start the timer
    my $t0 = [gettimeofday];

    my $bot = WWW::Mechanize->new();
    $bot->get($url);
    my $status = ($bot->success) ? 'success' : 'failed';

    # End time
    my $t1 = [gettimeofday];
    my $elapsed = tv_interval $t0,$t1;
    print join("\t",$status,$url,$elapsed),"\n";

    $count++;
    if ($count % 100 == 0) {
      print STDERR "Caching $class: $count pages cached...";
      print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
    }
  }
}

my $end = time();
my $seconds = $end - $start;
print "Time required to cache $count pages: ";
printf "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];

exit;

=pod

#############################################################
# CLASS REFERENCE
#############################################################

* Classes marked with an "*" are cached for the given release
  and should be visited by this script as well.

############################
# WS160                    #
############################
Anatomy_name
Anatomy_term
Antibody
Author
CDS
Cell
Clone
Database
Expression_cluster
Expr_pattern
Expr_profile
Feature
Feature_data
Genetic_map
Gene_class
Gene_name
Gene_regulation
Gene
Genome_Sequence
GO_code
GO_term
Grid
Homology_group
Journal
KO_allele
Laboratory
Lineage
Locus
Map
Method
Microarray
Microarray_experiment
Microarray_results
Motif
Oligo
Oligo_set
Operon
Paper
PCR_product
Person
Person_name
Phenotype
Protein
Pseudogene
Rearrangement
RNAi
Sequence
Sequence_map
SK_map
SO_term
Strain
Structure_data
Tag
Transcript
Transgene
Variation
Y2H

=cut
