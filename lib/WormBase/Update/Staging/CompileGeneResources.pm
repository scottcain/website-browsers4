package WormBase::Update::Staging::CompileGeneResources;

# Compile a nunch of flat-files that support the Gene Page. Eeeks.

use lib "/usr/local/wormbase/website/tharris/extlib";
use Ace;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile gene page resources',
    );

has 'datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir   = join("/",$self->support_databases_dir,$release,'gene');
    $self->_make_dir($datadir);
    return $datadir;
}

has 'dbh' => (
    is => 'ro',
    lazy_build => 1);

sub _build_dbh {
    my $self = shift;
    my $release = $self->release;
    my $acedb   = $self->acedb_root;
    my $dbh     = Ace->connect(-path => "$acedb/wormbase_$release") or $self->log->logdie("couldn't open ace:$!");
    return $dbh;
}


sub run {
    my $self = shift;
	    
    my $datadir = $self->datadir;
    
    my $gene_rnai_pheno_file = "gene_rnai_pheno.txt";
    my $gene_xgene_pheno_file = "gene_xgene_pheno.txt";
    my $variation_data_file = "variation_data.txt";
    my $rnai_data_file = "rnai_data.txt";
    my $phenotype_id2name_file = "phenotype_id2name.txt";
	
    $self->gene_rnai_pheno_data_compile("$datadir/$gene_rnai_pheno_file");
    $self->log->debug("gene_rnai_pheno_data_compile done");
	
    $self->gene_rnai_pheno_not_data_compile("$datadir/$gene_rnai_pheno_file");
    $self->log->debug("gene_rnai_pheno_not_data_compile done");
    
    $self->gene_xgene_pheno_data_compile("$datadir/$gene_xgene_pheno_file");
    $self->log->debug("gene_xgene_pheno_data_compile done");
    
    $self->variation_data_compile("$datadir/$variation_data_file");
    $self->log->debug("variation_data_compile done");
    
    $self->rnai_data_compile ("$datadir/$gene_rnai_pheno_file","$datadir/$rnai_data_file");
    $self->log->debug("rnai_data_compile done");
    
    $self->phenotype_id2name("$datadir/$phenotype_id2name_file");
    $self->log->debug("phenotype_id2name done");
    
}

sub gene_rnai_pheno_data_compile {
    my ($self,$outfile) = @_;
	
    open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open gene_rnai_pheno_data_compile output file");
    
    my $class = 'Gene';
    my @objects = $DB->fetch(-class => $class); #[, ] -count => 20, -offset=>6800 , , -name=>$gene_id
    
    foreach my $object (@objects) {	
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
		    print OUTFILE "$print_out_line\n";
		    $print_out_lines{$print_out_line} = 1;
		}
	    }
	}
    }
}

sub gene_rnai_pheno_not_data_compile {
    my ($self,$outfile) = @_;
	
    open OUTFILE, ">>$outfile" or $self->log->logdie("Cannot open gene_rnai_pheno_data_compile output file");
    
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
    my ($self,$output_file_name) = @_;
    my $class = 'Gene';				
    my @objects = $DB->fetch(-class => $class); #, -name=>$gene_id
    my %lines;
    
    open OUTPUT, ">$output_file_name" or $self->log->logdie("Cannot open gene_xgene_pheno_data_compile output file");
    
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
    my ($self,$output_file) = @_;
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
    my ($self, $grp_datafile,$output_file)  = @_;        
    my $class = 'RNAi';
    
    open DATAFILE, $grp_datafile or $self->log->logdie("Cannot open rnai_data_compile datafile");
    open OUTPUT, ">$output_file" or $self->log->logdie("Cannot open rnai_data_compile outfile");
    
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
	    
	    if ($experimental_detail =~ m/Genotype/) {		
		$genotype = $experimental_detail->right;
		print OUTPUT "$rnai_object\|$genotype\|$ref\n";
	    }
	    
	    if ($experimental_detail =~ m/Strain/) {		
		my $strain = $experimental_detail->right;
		$genotype = $strain->Genotype;
		print OUTPUT "$rnai_object\|$genotype\|$ref\n";
	    }	
	} 
	
	if (!($genotype)) {    
	    print OUTPUT "$rnai_object\|$genotype\|$ref\n";
	} else {	    
	    next;
	}
    }
}



sub phenotype_id2name{
    my ($self,$output_file) = @_;
    open OUTFILE, ">$output_file" or $self->log->logdie("Cannot open phenotype_id2name output file");
    
    my $class = 'Phenotype';
    my @pheno_objects = $DB->fetch(-class => $class); #, -name=>'WBPhenotype:0001380', , -count => 20, -offset=>6800
    
    foreach  my $pheno  (@pheno_objects) {	
    	my $pheno_term = $pheno->Primary_name;
    	print OUTFILE "$pheno\=\>$pheno_term\n";
    }
}

1;
