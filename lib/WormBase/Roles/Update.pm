package WormBase::Update::Config;

# Configuration options related to Staging and Production updates.

use Moose::Role;


# Logging options
has 'log_dir' => (
    is => 'ro',
    default => '/usr/local/wormbase/logs/staging',
    );




####################
#
# Helper scripts
#
####################

has 'create_blastdb_script' => ( is => 'ro', default => 'create_blastdb.sh' );





# Path to releases/species/SPECIES
has 'ftp_single_species_dir' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_ftp_single_species_dir {
    my $self = shift;    
    return join("/",$self->ftp_releases_dir,$self->release,'species',$self->species);
}












has 'blastdb_format_script' => (
    is => 'ro',
    default => '/usr/local/blast/bin/formatdb',
    );





1;





