#!/usr/bin/perl

use Ace;
use strict;

my 	%pheno_xgene;
our $DB = Ace->connect(-host=>'localhost', -port=>2005);
our $version = $DB->version;

## change to use Update.pm config 
our $indir = "/usr/local/wormbase/databases/$version/gene";
our $outdir = "/usr/local/wormbase/databases/$version/ontology";

my $outfile = "pheno2xgenes.txt";

open IN, "<$indir/gene_xgene_pheno.txt" or die "Can't open in file\n";
open OUT, ">$outdir/$outfile" or die "Can't open outfile\n"; 

while (<IN>) {

	my ($gene,$xgene,$pheno,$not) = split /\|/,$_;	
	$pheno_xgene{$pheno}{$xgene} = 1;
}

foreach my $phenotype (keys %pheno_xgene) {

	my $xgenes_ar = $pheno_xgene{$phenotype};
	my @xgenes = keys %$xgenes_ar;
	print OUT "$phenotype\=\>@xgenes\n";
}

print "OK\n";