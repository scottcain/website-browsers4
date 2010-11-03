#!/usr/bin/perl

use Ace;
use strict;

my %pheno_var;
my $nay = $ARGV[0];

our $DB = Ace->connect(-host=>'localhost', -port=>2005);
our $version = $DB->version;

## change to use Update.pm config 
our $indir = "/usr/local/wormbase/databases/$version/gene";
our $outdir = "/usr/local/wormbase/databases/$version/ontology";

my $outfile = "pheno2vars.txt";

if ($nay) {

	$outfile = "pheno2vars_not.txt";
}

open IN, "<$indir/variation_data.txt" or die "Can't open infile\n";
open OUT, ">$outdir/$outfile" or die "Can't open outfile\n"; 


while (<IN>) {

	my ($gene,$var,$pheno,$not,$seqd) = split /\|/,$_;
	
	if ($nay) {
		
		if($not =~ m/not/i) {
		
			$pheno_var{$pheno}{$var} = 1;	
		}
		else 
		{
			next;
		}
	}
	
	else {
	
		if ($not =~ m/not/i) {
		
			next;
		}
		else {
		
		$pheno_var{$pheno}{$var} = 1;
		}
	}

}

foreach my $phenotype (keys %pheno_var) {

	my $vars_ar = $pheno_var{$phenotype};
	my @vars = keys %$vars_ar;
	#my $rnais = join "|",@rnais;
	print OUT "$phenotype\=\>@vars\n";

}

print "OK\n";