#!/usr/bin/perl

use strict;
use Ace;

my $version = shift;
chomp $version;

# NO!!!!! This is using Ace on localhost. Might not be the current version.
#my $DB = Ace->connect(-host=>'localhost', -port=>2005);
my $DB = Ace->connect(-path=>"/usr/local/wormbase/acedb/wormbase_$version");
my @genes = $DB->fetch(-class =>'Gene'); ## ,-count=>10,-offset =>500

## TODO: pull this directory from Update.pm when building update script

my $datadir = "/usr/local/wormbase/databases/$version/ontology";


my %go_id2gene_id;
my %go_id2type;
my %gene_id2name;

open BP, ">$datadir/go_bp_id2gene_id.txt" or die "Can't open bp";
open MF, ">$datadir/go_mf_id2gene_id.txt" or die "Can't open bp";
open CC, ">$datadir/go_cc_id2gene_id.txt" or die "Can't open bp";

foreach my $gene (@genes) {

	my $gene_name = public_name($gene);
	$gene_id2name{$gene} = $gene_name; 
	
	my @go_terms = $gene->GO_Term;
	foreach my $go_term (@go_terms) {
		
		if (!($go_id2type{$go_term})) {
			$go_id2type{$go_term} = $go_term->Type;
		}
		
		$go_id2gene_id{$go_term}{$gene} = 1;	
	}	
}


foreach my $go_term (keys %go_id2gene_id) {
	
	my $gene_ids = $go_id2gene_id{$go_term};
	
	my @gene_names = map {$_ = $gene_id2name{$_}} (keys %$gene_ids);
	
		if($go_id2type{$go_term}=~ m/biological/i) {
	
			print BP "$go_term\=\>@gene_names\n"; ##$gene_id2name{$gene_id}
		}
		elsif ($go_id2type{$go_term}=~ m/function/i) {
		
			print MF "$go_term\=\>@gene_names\n";	##$gene_id2name{$gene_id}
		}
		else {
		
			print CC "$go_term\=\>@gene_names\n";	##$gene_id2name{$gene_id}
		}
	# foreach my $gene_id (keys %$gene_ids) {	}
}


sub public_name {

	my $object = shift @_;
	my $common_name = 
		$object->Public_name
		|| $object->CGC_name
		|| $object->Molecular_name
		|| eval { $object->Corresponding_CDS->Corresponding_protein }
		|| $object;
	
	return $common_name;
}
