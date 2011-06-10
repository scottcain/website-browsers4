package WormBase::Update::Staging::CompileGeneResources;

# Compile a bunch of flat-files that support the Gene Page. Eeeks.

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
    
    my $gene_rnai_pheno_file   = "gene_rnai_pheno.txt";
    my $gene_xgene_pheno_file  = "gene_xgene_pheno.txt";
    my $variation_data_file    = "variation_data.txt";
    my $rnai_data_file         = "rnai_data.txt";
    my $phenotype_id2name_file = "phenotype_id2name.txt";

    $self->log->info("creating gene_rnai_pheno.txt");	
    $self->gene_rnai_pheno_data_compile("$datadir/$gene_rnai_pheno_file");
    $self->log->debug("gene_rnai_pheno_data_compile done");


    $self->log->info("creating gene_rnai_pheno-not.txt");	
    $self->gene_rnai_pheno_not_data_compile("$datadir/$gene_rnai_pheno_file");
    $self->log->debug("gene_rnai_pheno_not_data_compile done");

    $self->log->info("creating gene_xgene_pheno.txt");	    
    $self->gene_xgene_pheno_data_compile("$datadir/$gene_xgene_pheno_file");
    $self->log->debug("gene_xgene_pheno_data_compile done");
    
    $self->log->info("creating variation_data.txt");
    $self->variation_data_compile("$datadir/$variation_data_file");
    $self->log->debug("variation_data_compile done");
    
    $self->log->info("creating rnai_data.txt");
    $self->rnai_data_compile ("$datadir/$gene_rnai_pheno_file","$datadir/$rnai_data_file");
    $self->log->debug("rnai_data_compile done");

    $self->log->info("creating phenotype_id2name.txt");    
    $self->phenotype_id2name("$datadir/$phenotype_id2name_file");
    $self->log->debug("phenotype_id2name done");    
}

sub gene_rnai_pheno_data_compile {
    my ($self,$outfile) = @_;
	
    open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open gene_rnai_pheno_data_compile output file");
    
    my $class = 'Gene';

    my $i = $self->dbh->fetch_many(-class=>$class);
    my $na = '';
    while (my $object = $i->next) {
	foreach my $rnai ($object->RNAi_result) {
	    
	    my @phenotypes = $rnai->Phenotype;
		
	    foreach my $interaction ($rnai->Interaction) {
		my @types = $interaction->Interaction_type;
		foreach (@types) {		    
		    push @phenotypes,map { $_->right } grep { $_ eq 'Interaction_phenotype' } $_->col;		    
		}
	    }
	    next unless @phenotypes > 0;

	    my %uniq = map { ("$object\|$rnai\|$_\|$na" => 1) } @phenotypes;
	    print OUTFILE join("\n",keys %uniq);
	}
	$self->dbh->memory_cache_clear();
    }
}

sub gene_rnai_pheno_not_data_compile {
    my ($self,$outfile) = @_;
	
    open OUTFILE, ">>$outfile" or $self->log->logdie("Cannot open gene_rnai_pheno_data_compile output file");
    
    my $class = 'Gene';

    my $i = $self->dbh->fetch_many(-class => $class);
    my $na = 'Not';
    while (my $object = $i->next) {
	my @rnai = $object->RNAi_result;    
	foreach my $rnai (@rnai) {
	    
	    my @phenotypes = $rnai->Phenotype_not_observed;
	    foreach my $phenotype (@phenotypes) {		
		print  OUTFILE "$object\|$rnai\|$phenotype\|$na\n";
	    }
	}
    }
}


sub gene_xgene_pheno_data_compile{
    my ($self,$output_file_name) = @_;

    my $class = 'Gene';
    my %lines;
    
    open OUTPUT, ">$output_file_name" or $self->log->logdie("Cannot open gene_xgene_pheno_data_compile output file");

    my $i = $self->dbh->fetch_many(-class => $class);
    while (my $object = $i->next) {
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
    
    open OUTFILE, ">$output_file" or die "Cannot open variation_data_compile output file\n";

    my $i = $self->dbh->fetch_many(-class => $class);
    while (my $object = $i->next) {
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
	
	my $rnai_object = $self->dbh->fetch(-class => $class, -name =>$unique_rnai); #, , -count => 20, -offset=>6800	
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
    my $i = $self->dbh->fetch_many(-class => $class);
    while (my $pheno = $i->next) {   
    	my $pheno_term = $pheno->Primary_name;
    	print OUTFILE "$pheno\=\>$pheno_term\n";
    }
}

1;
