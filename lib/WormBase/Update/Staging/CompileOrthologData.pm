package WormBase::Update::Staging::CompileOrthologyResources.pm;


use lib "/usr/local/wormbase/website/tharris/extlib";
use Ace;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile orthology resources',
    );

has 'datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir   = join("/",$self->support_databases_dir,$release,'orthology');
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

sub last_gene { 
	return shift->{last_gene}; 
}

sub run {
    my $self = shift;
    my $last_processed_gene = shift;
    my $datadir = $self->datadir;
    my $outfile = $datadir . "ortholog_other_data.txt";
    
	
    $self->log->info("creating ortholog_other_data.txt");	
    $self->get_all_ortholog_other_data($datadir, $last_processed_gene);   
    $self->log->debug("get_all_ortholog_other_data done");  
}

sub get_all_ortholog_other_data {
    my ($self,$datadir,$last_processed_gene) = @_;
    my $gene_list = "gene_list.txt";
    my $ortholog_other_data_txt_file = "ortholog_other_data.txt";
	my $last_processed_gene_txt = "last_processed_gene.txt";

	open GENELIST, "< $datadir/$gene_list" or die "Cannot open $gene_list for getting orthologs\n";

	my $gene_id;
	
	## iterate down list to last entry processed
	
	if ($last_processed_gene) {
		while (!($gene_id eq $last_processed_gene)) {
			$gene_id = <GENELIST>;
			chomp $gene_id;
		} 
	}

	open OUT, ">> $datadir/$ortholog_other_data_txt_file" or die "Cannot open $datadir/$ortholog_other_data_txt_file\n"; 
	
	foreach my $gene_id (<GENELIST>) {
		chomp $gene_id;
		my $gene = $DB->fetch(-class=>'Gene', -name=>$gene_id);
		print "processing\: $gene_id\n";
		my @ortholog_others;
		eval{ @ortholog_others = $gene->Ortholog_other;};
		
		foreach my $ortholog_other (@ortholog_others){
			my $method; 
		  	eval{$method = $ortholog_other->right(2);};
		  	my $protein_id;
			eval{$protein_id = $ortholog_other->DB_info->right(3);};
			my $db;
			eval{$db = $ortholog_other->DB_info->right;};
			my $fa;
			eval{$fa = "From_analysis";};
			my $species;
			eval{$species = $ortholog_other->Species;}; 
			print OUT "$gene\|$db\|$protein_id\|$species\|$fa\|$method\n";
        }
		system("echo $gene_id > $datadir/$last_processed_gene_txt");		
	}	
}

1;
