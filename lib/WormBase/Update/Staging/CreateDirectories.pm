package WormBase::Update::Staging::CreateDirectories;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'creating directories',
    );

my @directories = qw/blast blat epcr ontology tiling_array interaction orthology position_matrix gene/;


sub run {
    my $self = shift;
    my $release        = $self->release;    
    my $support_db_dir = $self->support_databases_dir;
    $self->_make_dir($support_db_dir);
    $self->_make_dir("$support_db_dir/$release");
    
    foreach (@directories) {
	$self->_make_dir("$support_db_dir/$release/$_");
    }
}

1;
