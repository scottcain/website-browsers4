#!/usr/bin/perl

use strict;
use Ace;
$|++;

my $path = shift or warn "Usage: dump_urls.pl [/path/to/release] (now using aceserver for testing)";

my $db;
#if ($path) {
#    $db = Ace->connect(-path => $path);
#} else {
    $db = Ace->connect(-host => 'localhost',-port => 2005);
#}

my $version = $db->status->{database}{version};
open OUT,">url_lists/$version-urls.txt";

use constant ROOT_URL   => 'http://www.wormbase.org/db';
use constant USE_GET    => 0;
use constant GET        => ROOT_URL . '/get?name=%s;class=%s';
use constant ATTRIBUTES => 'changefreq=monthly';
my %counts;
my %classes = (
#	      All_genes
	      Anatomy_name    => { 
		  url => ROOT_URL . '/ontology/anatomy?name=%s;class=%s',
		  priority => '0.1' },
	      Anatomy_term    => { 
		  url => ROOT_URL . '/ontology/anatomy?name=%s;class=%s',
		  priority => '0.3' },
	      Antibody        => { 
		  url => ROOT_URL . '/gene/antibody?name=%s;class=%s',
		  priority => '0.3' },
#	      Author          => { priority => '0.3' },
#	      briggsae_CDS
#	      Briggsae_genomic
#	      briggsae_pseudogenes
#	      briggsae_RNA_genes
#	      Brigpep
#	      cDNA_Sequence
#	      CDS     => { priority => '0.4' },
#	      Cell    => { priority => '0.5' },
#	      Cell_group => { priority => '0.1' },
	      Clone   => {
		  url => ROOT_URL . '/seq/clone?name=%s;class=%s',
		  priority => '0.4' },
#	      Coding_transcripts
#	      Condition
#	      curated_CDS
#	      Database
#	      Deletion_allele
#	      elegans_CDS
#	      elegans_pseudogenes
#	      elegans_RNA_genes
#	      elegans_transposons
#	      Expression_cluster => { priority => '0.1' },
	      Expr_pattern       => { 
		  url => ROOT_URL . '/gene/expression?name=%s;class=%s',
		  priority => '0.3' },
#	      Expr_profile       => { priority => '0.1' },
#	      Feature            => { priority => '0.1' },
#	      Feature_data
	      Gene => {
		  url      => ROOT_URL . '/gene/gene?name=%s;class=%s',
		  priority => '1.0',
	      },
#	      Genetic_code
#	      Genetic_map
	       Gene_class  => {
		   url => ROOT_URL . '/gene/gene_class?name=%s;class=%s',
		   priority => '0.4' },
# Not necessary to index the *name classes - these objects point to the same URL
# as the primary class (and the *name entry *should* appear on the page and be indexed
#	      Gene_name   => { priority => '0.4' },
	       Gene_regulation => {
		   url => ROOT_URL . '/gene/regulation?name=%s;class=%s',
		   priority => '0.3' },
#	      Genome_Sequence
#	      GO_code => { priority => '0.1' },
	      GO_term => { 
		  url => ROOT_URL . '/gene/ontology?name=%s;class=%s',
		  priority => '0.3' },
#	      Grid
	      Homology_group => {
		  url => ROOT_URL . '/gene/homology_group?name=%s;class=%s',
		  priority => '0.5' },
#	      Homol_data
#	      Insertion_allele
#	      Journal
#	      KeySet
#	      KO_allele
	      Laboratory => { 
		  url => ROOT_URL . '/misc/laboratory?name=%s;class=%s',
		  priority => '0.3' },
	      Life_stage => {
		  url => ROOT_URL . '/misc/life_stage?name=%s;class=%s',
		  priority => '0.3' },
#	      Lineage 
#	      Live_genes
#	      Locus => { priority => '0.1' },
#	      Map
#	      Method
#	      Microarray => { priority => '0.1' },
#	      Microarray_experiment => { priority => '0.1' },
#	      Microarray_results => { priority => '0.1' },
#	      Model
	      Motif => {
		  url => ROOT_URL . '/gene/motif?name=%s;class=%s',
		  priority => '0.1' },
#	      NBP_allele
#	      NDB_Sequence
#	      nematode_ESTs
#	      Oligo       => { priority => '0.1' },
#	      Oligo_set   => { priority => '0.1' },
	      Operon      => {
		  url => ROOT_URL . '/gene/operon?name=%s;class=%s',
		  priority => '0.1' },
	      Paper       => {
		  url => ROOT_URL . '/misc/paper?name=%s;class=%s',
		  priority => '0.5' },
	      PCR_product => {
		  url => ROOT_URL . '/seq/pcr?name=%s;class=%s',
		  priority => '0.1' },
	       Person      => {
		   url => ROOT_URL . '/misc/person?name=%s;class=%s',
		   priority => '0.3' },
	      Person_name => {
		  url => ROOT_URL . '/misc/person?name=%s;class=%s',
		  priority => '0.3' },
	       Phenotype   => {
		   url => ROOT_URL . '/misc/phenotype?name=%s;class=%s',
		   priority => '0.5' },
	      Protein     => {
		  url      => ROOT_URL . '/seq/protein?name=%s;class=%s',
		  priority => '0.7',
	      },	     	      
	       Wormpep     => {
		   url      => ROOT_URL . '/seq/protein?name=%s;class=%s',
		   priority => '0.7',
	       },	     	      
#	      Pseudogene
	      Rearrangement => {
		  url => ROOT_URL . '/gene/rearrange?name=%s;class=%s',
		  priority => '0.1' },
#	      Restrict_enzyme
	      RNAi => {
		  url => ROOT_URL . '/seq/rnai?name=%s;class=%s',
		  priority => '0.4' },
#	      Sage_tag => { priority => '0.1' },
#	      Sequence => {
#		  url      => ROOT_URL . '/seq/sequence?name=%s;class=%s',
#		  priority => '0.1',
#	      },
#	      Sequence_map
#	      SK_map
#	      SO_term
	      Strain => {
		  url => ROOT_URL . '/gene/strain?name=%s;class=%s',
		  priority => '0.4' },
#	      Structure_data => { priority => '0.1' },
#	      Substitution_allele
#	      Tag
#	      Transcript => { priority => '0.2' },
	      Transgene  => {
		  url => ROOT_URL . '/gene/transgene?name=%s;class=%s',
		  priority => '0.3' },
#	       Transposon => { priority => '0.1' },
#	      Transposon_family => { priority => '0.1' },
#	      Tree
	      Variation => {
		  url => ROOT_URL . '/gene/variation?name=%s;class=%s',
		  priority => '0.6' },
#	      View
#	      Wormpep
#	      worm_genes
#	      Y2H => { priority => '0.1' },
	       );

foreach (sort keys %classes) {
  fetch_features($_);
  print STDERR "$_ $counts{$_}\n";
}



sub fetch_features {
    my $class = shift;
    my @features;
#  if ($class eq 'Protein') {
#      @features = $db->fetch(-query=>qq/find Protein where Species="C*elegans"/);
#  } else {
    @features = $db->fetch($class => '*');
#  }
    foreach my $feat (@features) {
#      next if ($class eq 'Protein' && $feat->Species ne 'Caenorhabditis elegans');
	my $target = encode($feat);
	$counts{$class}++;
	
	my $url;
	if (USE_GET) {
	    $url = GET;
	} else {
	    $url = $classes{$class}{url};
	}
	
	# Append the priority if one has been set
	my $priority = eval { $classes{$class}{priority} } || '0.1';
	my $string = sprintf($url,$target,$class) . ' ' . join(' ',ATTRIBUTES,"priority=$priority") . "\n";
	print OUT $string;
    }
}


sub encode {
    my $target = shift;
    $target =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
    return $target;
}


# update the symlink so the site map generator script can find it
unlink("current_urls.txt");
symlink("url_lists/$version-urls.txt",'current_urls.txt');
