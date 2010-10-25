package Update::CompileGeneResources; 

use strict;
use base 'Update';
use Ace;

our $DB = Ace->connect(-host=>'localhost', -port=>2005);
our $gene_id = 'WBGene00000912';

# The symbolic name of this step
sub step { return 'compiling gene resources'; }

sub run {

	my $self = shift;
	my $release = $self->release;
	my $support_db_dir = $self->support_dbs;
	
	my $datadir = $support_db_dir . "/$release/gene_test";
	my $gene_rnai_pheno_file = "gene_rnai_pheno.txt";
	my $gene_xgene_pheno_file = "gene_xgene_pheno.txt";
	my $variation_data_file = "variation_data.txt";
	my $rnai_data_file = "rnai_data.txt";
	my $phenotype_id2name_file = "phenotype_id2name.txt";
	
	$self->gene_rnai_pheno_data_compile("$datadir/$gene_rnai_pheno_file");
	print "gene_rnai_pheno_data_compile done\n";
	
	$self->gene_rnai_pheno_not_data_compile("$datadir/$gene_rnai_pheno_file");
	print "gene_rnai_pheno_not_data_compile done\n";
	
	$self->gene_xgene_pheno_data_compile("$datadir/$gene_xgene_pheno_file");
	print "gene_xgene_pheno_data_compile done\n";
	
	$self->variation_data_compile("$datadir/$variation_data_file");
	print "variation_data_compile done\n";
	
	$self->rnai_data_compile ("$datadir/$gene_rnai_pheno_file","$datadir/$rnai_data_file");
	print "rnai_data_compile done\n";
	
	$self->phenotype_id2name("$datadir/$phenotype_id2name_file");
	print "phenotype_id2name done\n";

}

sub gene_rnai_pheno_data_compile {

	my $self = shift @_;
	my $outfile = shift @_;	
	
	open OUTFILE, ">$outfile" or die "Cannot open gene_rnai_pheno_data_compile output file\n"; #
	
	my $class = 'Gene';
	my @objects = $DB->fetch(-class => $class); #[, ] -count => 20, -offset=>6800 , , -name=>$gene_id
	
	foreach my $object (@objects){
	
		my @rnai = $object->RNAi_result;    
		
		foreach my $rnai (@rnai) {
						
			my @phenotypes = $rnai->Phenotype;
			my $na = '';
		
			foreach my $interaction ($rnai->Interaction) {
				my @types = $interaction->Interaction_type;
				foreach (@types) {
				
					push @phenotypes,map { $_->right } grep { $_ eq 'Interaction_phenotype' } $_->col;
				}
			}

			my %print_out_lines;
			
			foreach my $phenotype (@phenotypes) {
				
				my $print_out_line = "$object\|$rnai\|$phenotype\|$na";
				
				if ($print_out_lines{$print_out_line}) {
				
					next;
				} else {
				
					print  OUTFILE "$print_out_line\n";
					$print_out_lines{$print_out_line} = 1;
				}
			
				  ### 
			}
		}
	}
}

sub gene_rnai_pheno_not_data_compile {


	my $self = shift @_;
	my $outfile = shift @_;	
	
	open OUTFILE, ">>$outfile" or die "Cannot open gene_rnai_pheno_data_compile output file\n"; #
	
	my $class = 'Gene';
	my @objects = $DB->fetch(-class => $class); #[, ] -count => 20, -offset=>6800 ,-name=>$gene_id
	
	foreach my $object (@objects){
	
		my @rnai = $object->RNAi_result;    
		
		foreach my $rnai (@rnai) {
							
			my @phenotypes = $rnai->Phenotype_not_observed;
			my $na = '';
			$na = 'Not';
				
			foreach my $phenotype (@phenotypes) {
			
				print  OUTFILE "$object\|$rnai\|$phenotype\|$na\n"; ### 
			}
		}
	}
}


sub gene_xgene_pheno_data_compile{

	my $self = shift @_;
	my $output_file_name = shift @_;
	my $class = 'Gene';				
	my @objects = $DB->fetch(-class => $class); #, -name=>$gene_id
	my %lines;
	
	open OUTPUT, ">$output_file_name" or die "Cannot open gene_xgene_pheno_data_compile output file\n";
	
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
}

 
sub variation_data_compile{
	
	my $self = shift @_;
	my $output_file = shift @_;
	
	my $class = 'Gene';				
	my @objects = $DB->fetch(-class => $class); #, -name=>$gene_id ,, -count => 20, -offset=>6800
	
	
	open OUTFILE, ">$output_file" or die "Cannot open variation_data_compile output file\n";
	
	foreach my $object (@objects){
	
		my @variations = $object->Allele;
		foreach my $variation (@variations) {
	
			my $seq_status = $variation->SeqStatus;
			my $variation_name = $variation->Public_name;
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
					
				print  OUTFILE "$object\|$variation\|$phenotype\|$na\|$seq_status\|$variation_name\n";

			}
		}
	}
}


sub rnai_data_compile{


my $class = 'RNAi';
my ($self, $grp_datafile,$output_file)  = @_;


open DATAFILE, $grp_datafile or die "Cannot open rnai_data_compile datafile\n";
open OUTPUT, ">$output_file" or die "Cannot open rnai_data_compile outfile\n";

my %rnais;


foreach my $dataline (<DATAFILE>) {

	chomp $dataline;
	my ($gene,$rnai,$pheno,$not) = split /\|/,$dataline;
	$rnais{$rnai} = 1;
}

foreach my $unique_rnai (keys %rnais) {

	my $rnai_object = $DB->fetch(-class => $class, -name =>$unique_rnai); #, , -count => 20, -offset=>6800	
	my $ref;
	
	eval { $ref = $rnai_object->Reference;}; 
	
	my $genotype;
	my @experimental_details; # = $rnai_object->Experiment;

	eval {@experimental_details = $rnai_object->Experiment;};

	foreach my $experimental_detail (@experimental_details) {
			
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
	
	my $self = shift @_;
	my $output_file = shift @_;
	open OUTFILE, ">$output_file" or die "Cannot open phenotype_id2name output file";

	my $class = 'Phenotype';
	my @pheno_objects = $DB->fetch(-class => $class); #, -name=>'WBPhenotype:0001380', , -count => 20, -offset=>6800

	foreach  my $pheno  (@pheno_objects) {

    	my $pheno_term = $pheno->Primary_name;
    	print OUTFILE "$pheno\=\>$pheno_term\n";
	}
}

1;
