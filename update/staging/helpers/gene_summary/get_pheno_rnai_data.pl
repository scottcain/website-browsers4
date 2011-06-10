#!/usr/bin/perl

#use Ace;
use strict;

my $version = shift;
my $nay = shift;

chomp $version;
chomp $nay;

my 	%pheno_rnai;



#our $DB = Ace->connect(-host=>'localhost', -port=>2005);
#our $version = $DB->version;

## change to use Update.pm config 
our $indir = "/usr/local/wormbase/databases/$version/gene";
our $outdir = "/usr/local/wormbase/databases/$version/ontology";

my $outfile = "pheno2rnais.txt";

if ($nay) {

	$outfile = "pheno2rnais_not.txt";
}

open IN, "<$indir/gene_rnai_pheno.txt" or die "Can't open infile\n";
open OUT, ">$outdir/$outfile" or die "Can't open outfile\n"; 



while (<IN>) {

	my ($gene,$rnai,$pheno,$not) = split /\|/,$_;
	
	if ($nay) {
		
		if($not =~ m/not/i) {
		
			$pheno_rnai{$pheno}{$rnai} = 1;
	
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
		
		$pheno_rnai{$pheno}{$rnai} = 1;
		}
	}

}

foreach my $phenotype (keys %pheno_rnai) {

	my $rnais_ar = $pheno_rnai{$phenotype};
	my @rnais = keys %$rnais_ar;
	#my $rnais = join "|",@rnais;
	print OUT "$phenotype\=\>@rnais\n";

}

print "OK\n";
