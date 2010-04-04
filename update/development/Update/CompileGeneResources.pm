package Update::CompileGeneResources; #

use base 'Update';
use strict;
use Ace;

our $support_db_dir;
our $datadir;
our $release;

our $DB = Ace->connect(-host=>'localhost', -port=>2005);

our $gene_rnai_pheno_file;
our $gene_xgene_pheno_file;
our $variation_data_file;
our $rnai_data_file;
our $phenotype_id2name_file;

sub step {return 'compile interaction data';}

sub run { 

	my $self = shift @_;
	
	$release = $self->release;
	$support_db_dir = $self->support_dbs; # ".";
	$datadir = $support_db_dir . "\/$release\/gene_test"; # "/""/orthology_data/$release"
	$gene_rnai_pheno_file = $datadir . "\/gene_rnai_pheno.txt";
	$gene_xgene_pheno_file = $datadir . "\/gene_xgene_pheno.txt";
	$variation_data_file = $datadir . "\/variation_data.txt";
	$rnai_data_file = $datadir . "\/rnai_data.txt";
	$phenotype_id2name_file = $datadir . "\/phenotype_id2name.txt";

	print "Compiling gene, rnai, and pheno data.\n";
	$self->gene_rnai_pheno_data_compile($gene_rnai_pheno_file);
	print "Compiling gene, transgene, and pheno data\n";
	$self->gene_xgene_pheno_data_compile($gene_xgene_pheno_file);
	print "Compiling variation data\n";
	$self->variation_data_compile($variation_data_file);
	print "Compiling rnai data\n";
	$self->rnai_data_compile ($gene_rnai_pheno_file,$rnai_data_file);
	print "Compiling pheno id2name data\n";
	$self->phenotype_id2name($phenotype_id2name_file);

	print "Gene data resources compile done\n";	

}

### subroutines

sub gene_rnai_pheno_data_compile {

	#my $output_file = shift @_;
	
	open OUTFILE, ">$gene_rnai_pheno_file" or die "Cannot open gene_rnai_pheno_data_compile output file\n"; #
	
	my $class = 'Gene';
					
	my @objects = $DB->fetch(-class => $class); #[, -count => 20, -offset=>6800 ] 
	
	foreach my $object (@objects){
	
		my @rnai = $object->RNAi_result;    
		foreach my $rnai (@rnai) {
			my @phenotypes = $rnai->Phenotype;
		
			foreach my $interaction ($rnai->Interaction) {
				my @types = $interaction->Interaction_type;
				foreach (@types) {
		   
				push @phenotypes,map { $_->right } grep { $_ eq 'Interaction_phenotype' } $_->col;
					}
			}
			
			foreach my $phenotype (@phenotypes) {
				my $not_attribute = $phenotype->right;
				my $na;
				if ($not_attribute =~ m/not/i){
				
					$na = $not_attribute;
				
				} else {
				
					$na = "";
				
				}
				
				print OUTFILE "$object\|$rnai\|$phenotype\|$na\n";
			
			}	
		}
	}

}  ## end gene_rnai_pheno_data_compile

sub gene_xgene_pheno_data_compile{

	# my $output_file_name = shift @_;
	my $class = 'Gene';				
	my @objects = $DB->fetch(-class => $class);
	my %lines;
	
	open OUTPUT, ">$gene_xgene_pheno_file" or die "Cannot open gene_xgene_pheno_data_compile output file\n";
	
	foreach my $object (@objects){
	
		my @xgenes = $object->Drives_Transgene;
		my @xgene_product = $object->Transgene_product;
		my @xgene_rescue = $object->Rescued_by_transgene;
		
		push @xgenes,@xgene_product;
		push @xgenes,@xgene_rescue;
		
		foreach my $xgene (@xgenes) {

			my @phenotypes = $xgene->Phenotype;
		
			foreach my $phenotype (@phenotypes) {
				my $not_attribute = $phenotype->right;
				my $na;
				if ($not_attribute =~ m/not/i){
				
					$na = $not_attribute;
				
				} else {
				
					$na = "";
				
				}
				
				$lines{"$object\|$xgene\|$phenotype\|$na"} = 1;
			
			}	
		}
	}
	
	foreach my $line (keys %lines) {
	
		print OUTPUT "$line\n";
	
	}

} ## end gene_xgene_pheno_data_compile
 
sub variation_data_compile{
	
	my $class = 'Gene';				
	my @objects = $DB->fetch(-class => $class ); #,, -count => 20, -offset=>6800
	
	#my $output_file = shift @_;
	open OUTFILE, ">$variation_data_file" or die "Cannot open variation_data_compile output file\n";
	
	foreach my $object (@objects){
	
	#	print "\n\:$object\:\n";
		
		my @variations = $object->Allele;
		foreach my $variation (@variations) {
	
			my 	$seq_status = $variation->SeqStatus;
				
			my @phenotypes = $variation->Phenotype;
			
				foreach my $phenotype (@phenotypes) {
					
					my @attributes = $phenotype->col;
					my $na = "";
					foreach my $attribute (@attributes) {
					
						if ($attribute =~ m/^not$/i){
		
							$na = $attribute;
				  
						} else {
							
						next;
		
						}
					}
					
				print  OUTFILE "$object\|$variation\|$phenotype\|$na\|$seq_status\n";
				
				}
			}
	}
}

sub rnai_data_compile{


my $class = 'RNAi';

#my ($grp_datafile,$output_file)  = @_;


open DATAFILE, $gene_rnai_pheno_file or die "Cannot open rnai_data_compile datafile\n";
open OUTPUT, ">$rnai_data_file" or die "Cannot open rnai_data_compile outfile\n";

my %rnais;


foreach my $dataline (<DATAFILE>) {

	chomp $dataline;
	my ($gene,$rnai,$pheno,$not) = split /\|/,$dataline;
	$rnais{$rnai} = 1;
	#print "$dataline\n";

}

foreach my $unique_rnai (keys %rnais) {

	my $rnai_object = $DB->fetch(-class => $class, -name =>$unique_rnai); #, , -count => 20, -offset=>6800
	
	my $ref = $rnai_object->Reference;
	my $genotype;
	
	my @experimental_details = $rnai_object->Experiment;
	
	foreach my $experimental_detail (@experimental_details) {
	
		# print "$experimental_detail\n";
			
		if($experimental_detail =~ m/Genotype/) {
		
			$genotype = $experimental_detail->right;
			print OUTPUT "$rnai_object\|$genotype\|$ref\n";
		
		}
		
		if($experimental_detail =~ m/Strain/) {
		
			my $strain = $experimental_detail->right;
			$genotype = $strain->Genotype;
			print OUTPUT "$rnai_object\|$genotype\|$ref\n";
		
		}	
	
	} 

	if(!($genotype)) {
		
		print OUTPUT "$rnai_object\|$genotype\|$ref\n";
	
	} else {
	
		next;
	
	}

}



}

sub phenotype_id2name{

	open OUTFILE, ">$phenotype_id2name_file" or die "Cannot open output file "; #$output_file

	my $class = 'Phenotype';
	
	my @pheno_objects = $DB->fetch(-class => $class); #, , -count => 20, -offset=>6800
	
	foreach  my $pheno  (@pheno_objects) {
	
		my $pheno_term = $pheno->Primary_name;
		print  OUTFILE "$pheno\=\>$pheno_term\n"; ### 
	
	}
}

1;


