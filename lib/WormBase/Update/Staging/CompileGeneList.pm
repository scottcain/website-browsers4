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


sub run {
    my $self = shift;
    my $datadir = $self->datadir;
    my $outfile = $datadir . "gene_list.txt";
    
    $self->log->info("creating gene_list.txt");	
    $self->get_genes_with_orthologs>($outfile);   
    $self->log->debug("get_genes_with_orthologs done");
    
}

sub get_genes_with_orthologs {
    my ($self,$outfile) = @_;
    open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open gene_list output file");
    my $class = 'Gene';
	my $genes = $self->dbh->fetch_many(-class => $class);
	
	while(my $gene = $genes->next){
		my @oo = $gene->Ortholog_other;
		
		if (@oo) {
			print OUTFILE "$gene\n";
		} else 
		{
			next;
		}
	}
	close OUTFILE;
}

1;
