#!/usr/bin/perl

use Ace;
use strict;

my %pheno_gene;
my %genes;
my %gene_id2name;

our $DB = Ace->connect(-host=>'localhost', -port=>2005);
our $version = $DB->version;

## change to use Update.pm config 
our $indir = "/usr/local/wormbase/databases/$version/gene";
our $outdir = "/usr/local/wormbase/databases/$version/ontology";


open IN_XGENE, "<$indir/gene_xgene_pheno.txt" or die "Can't open in file $indir/gene_xgene_pheno.txt\n";
open IN_VAR,"<$indir/variation_data.txt" or die "Can't open in file $indir/variation_data.txt\n";
open IN_RNAi, "<$indir/gene_rnai_pheno.txt" or die "Can't open in file $indir/gene_rnai_pheno.txt\n";
open OUT, ">$outdir/pheno2gene_names_not.txt" or die "Can't open out file $outdir/pheno2gene_names_not.txt\n";

system ("echo 'fetching xgene related data'");

while (<IN_XGENE>) {

	my ($gene,$xgene,$pheno,$not) = split /\|/,$_;
	
	if(!($not)) {
		
		next;
	}
	
	else {
		
		$pheno_gene{$pheno}{$gene} = 1;
		$genes{$gene} = 1;
	}
}

system ("echo 'fetching variation related data'");

while (<IN_VAR>) {

	my ($gene,$var,$pheno,$not,$seqd) = split /\|/,$_;

	if(!($not)) {
		
		next;
	}
	else {
	
		$pheno_gene{$pheno}{$gene} = 1;
		$genes{$gene} = 1;
	}
}

system ("echo 'fetching RNAi related data'");

while (<IN_RNAi>) {

	my ($gene,$rnai,$pheno,$not) = split /\|/,$_;
	
	if(!($not)) {
		
		next;
	}
	
	else {
	
		$pheno_gene{$pheno}{$gene} = 1;
		$genes{$gene} = 1;
	}
}


system ("echo 'getting gene names'");

foreach my $gene_id (keys %genes) {

		my $gene_obj = $DB->fetch(-class=>'Gene',-name=>$gene_id);
		my $gene_cgc = $gene_obj->CGC_name;
		my $gene_seq = $gene_obj->Sequence_name;

		$gene_id2name{$gene_id} = $gene_seq;
		$gene_id2name{$gene_id} = $gene_cgc;
}

system ("echo 'printing data'");

foreach my $phenotype (keys %pheno_gene) {

	my $genes_ar = $pheno_gene{$phenotype};
	my @genes = keys %$genes_ar;
	my @gene_names = map {$_ = $gene_id2name{$_}} @genes;
	#my $rnais = join "|",@rnais;
	
	print OUT "$phenotype\=\>@gene_names\n";

}

system ("echo 'OK'");