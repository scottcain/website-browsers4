package WormBase::Species;

# A collection of one or possibly many bioproject IDs
# and miscellaneous meta-information about the species.


# A simple species package that makes tracking
# available resources for that species trivial.
# Each species is associated with a release to 
# make construction of these filenames possible.

use Moose;

with 'WormBase::Roles::Config';

has 'symbolic_name' => ( is => 'rw' );
has 'release'       => ( is => 'rw' );

# One or possibly many bioprojects per species.
has 'bioprojects' => ( is => 'rw',lazy_build => 1);
sub _build_bioprojects {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $dir    = join("/",$self->ftp_releases_dir,$release,'species',$name);
    
    opendir(DIR,"$dir") or die "Couldn't open the species directory ($dir) on the FTP site.";
    my @children = grep { !/^\./ && -d "$dir/$_" } readdir(DIR);
   
    my @bioprojects;
    foreach my $id (@children) {
	my $bioproject = WormBase->create('Species::Bioproject',{ bioproject_id => $id, symbolic_name => $name, release => $release });
	push @bioprojects,$bioproject;
    }

    return \@bioprojects;
}


1;
