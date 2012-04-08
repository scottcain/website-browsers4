package WormBase::Update::Staging::CompileOntologyResources;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile ontology resources',
    );

has 'datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir   = join("/",$self->support_databases_dir,$release,'ontology');
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
    my $dbh     = Ace->connect(-path => "$acedb/wormbase_$release") or $self->log->warn("couldn't open ace:$!");
    $dbh = Ace->connect(-host => 'localhost',-port => 2005) unless $dbh;    
    return $dbh;
}


sub run {
    my $self = shift;
    my $release = $self->release;
    
    # The ontology directory should already exist. Let's make certain.    
    my $datadir = $self->support_databases_dir. "/$release/ontology";

    $self->copy_ontology();   

    $self->log->info("ontology compiles complete");
}


sub copy_ontology {
    my $self = shift;
    my $release = $self->release;
    my $source = join("/",$self->ftp_releases_dir,$release,'ONTOLOGY');
    my $target = join("/",$self->support_databases_dir,$release,'ontology');
    $self->system_call("cp $source/*.wb $target",
		       "copying ontology");

}


1;

=cut








1;
