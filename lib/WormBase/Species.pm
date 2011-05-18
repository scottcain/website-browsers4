package WormBase::Species;

# A simple species package that makes tracking
# available resources for that species trivial.
# Each species is associated with a release to 
# make construction of these filenames possible.

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use File::Slurp qw(slurp);
extends qw/WormBase/;

with 'WormBase::Roles::Config';

has 'symbolic_name' => ( is => 'rw' );
has 'release'       => ( is => 'rw' );


# The release directory for this species on the FTP site.
has 'release_dir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_release_dir {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $dir = join("/",$self->ftp_releases_dir,$release,$name);
    return $dir;
}


has 'blast_dir' => (
    is      => 'ro',
    lazy    => 1,
);

sub _build_blast_dir { 
    my $self = shift;
    my $release = $self->release;
    my $name    = $self->symbolic_name;
    my $path = join('/',$self->support_databases_dir,$release,'blat');
    $self->_make_dir($path);

    $self->_make_dir("$path/$name");
    return "$path/$name";
}

has 'blat_dir' => (
    is      => 'ro',
    lazy    => 1,
);

sub _build_blat_dir { 
    my $self = shift;
    my $release = $self->release;
    my $name    = $self->symbolic_name;
    my $path = join('/',$self->support_databases_dir,$release,'blat');
    $self->_make_dir($path);

    $self->_make_dir("$path/$name");
    return "$path/$name";
}


######################################################
#
#   Filenames
#
######################################################

# Discover the name of the fasta file for a given species.
# More appropriate as a Role.
has 'fasta_file' => (
    is => 'ro',
    lazy_build => 1);

sub _build_fasta_file {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $fasta   = "$name.$release.genomic.fa.gz";
    return $fasta;
}


1;
