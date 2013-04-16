package WormBase::Species::Bioproject;

# Each species can have one or possibly many bioprojects.
# These are instantiated by the Species class.

# Serves up file paths and file names for a given
# species/bioproject combination

use Moose;

with 'WormBase::Roles::Config';

has 'symbolic_name' => ( is => 'rw' );
has 'release'       => ( is => 'rw' );
has 'bioproject_id' => ( is => 'rw' );

# Database symbolic name. Mostly for MySQL
has 'mysql_db_name' => (
    is => 'rw',
    lazy_build => 1 );

sub _build_mysql_db_name {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;
    my $id      = $self->bioproject_id;
    return $name . '_' . $id . '_' . $release;
}




# The release directory for this species on the FTP site.
has 'release_dir' => ( is => 'ro', lazy_build => 1);
sub _build_release_dir {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $id      = $self->bioproject_id;

    # my $dir = join("/",$self->ftp_releases_dir,$release,'species',$name)
    my $dir = join("/",$self->ftp_releases_dir,$release,'species',$name,$id);
    return $dir;
}


has 'blast_dir' => ( is => 'ro', lazy_build => 1 );
sub _build_blast_dir { 
    my $self = shift;
    my $release = $self->release;
    my $name    = $self->symbolic_name;
    my $id      = $self->bioproject_id;
    my $path = join('/',$self->support_databases_dir,$release);
    $self->_make_dir($path);
    $self->_make_dir("$path/blast");
    $self->_make_dir("$path/blast/$name");
    $self->_make_dir("$path/blast/$name/$id");
    return "$path/blast/$name/$id";
}

has 'blat_dir' => ( is => 'ro', lazy_build => 1 );
sub _build_blat_dir { 
    my $self = shift;
    my $release = $self->release;
    my $name    = $self->symbolic_name;
    my $id      = $self->bioproject_id;
    my $path = join('/',$self->support_databases_dir,$release);
    $self->_make_dir($path);
    $self->_make_dir("$path/blat");
    $self->_make_dir("$path/blat/$name");
    $self->_make_dir("$path/blat/$name/$id");
    return "$path/blat/$name/$id";
}



has 'epcr_dir' => ( is => 'ro', lazy_build => 1 );
sub _build_epcr_dir { 
    my $self = shift;
    my $release = $self->release;
    my $name    = $self->symbolic_name;
    my $path    = join('/',$self->support_databases_dir,$release);
    my $id      = $self->bioproject_id;
    $self->_make_dir($path);
    $self->_make_dir("$path/epcr");
    $self->_make_dir("$path/epcr/$name");
    $self->_make_dir("$path/epcr/$name/$id");
    return "$path/epcr/$name/$id";
}




has 'has_been_updated' => ( is => 'rw' , lazy_build => 1 );

# Return a boolean value if the CURRENT
# release for this bioproject has been
# updated relative to the last
# using checksums of the annotation file.
# This won't be available until WS238
sub _build_has_been_updated {
    my $self = shift;
    my $this_gff_file = $self->gff_file;
    my $release       = $self->release;
    my ($id)          = ($release =~ /WS(\d\d\d)/); 
    $id--;
    my $last_gff_file = $this_gff_file;
    $last_gff_file    =~ s/$release/WS$id/g;

# Until WS238, won't be able to tell what has been updated. 
    # I need two releases with the same structure.
    
    return 1;   

    # Do the checksum.
    my $this_md5 = $self->create_md5($self->release_dir,$this_gff_file);
    my $last_md5 = $self->create_md5($self->release_dir,$last_gff_file);

    # The md5 for the annotation file is the same.
    # Let's assume we haven't been updated.
    if ($this_md5 eq $last_md5) {
	return 0;
    } else {
	# Otherwise, the checksums are DIFFERENT.
	# We have been updated. Do something.
	return 1; # We've been updated.
    }    
}


######################################################
#
#   Filenames
#
######################################################

# Discover the name of the fasta file for a given species.
# More appropriate as a Role.
has 'genomic_fasta' => (
    is => 'ro',
    lazy_build => 1);

sub _build_genomic_fasta {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $id      = $self->bioproject_id;
    my $fasta   = "$name.$id.$release.genomic.fa.gz";
    return $fasta;
}

# Discover the name of the fasta file for a given species.
# More appropriate as a Role.
has 'protein_fasta' => (
    is => 'ro',
    lazy_build => 1);

sub _build_protein_fasta {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $id      = $self->bioproject_id;
    my $fasta   = "$name.$id.$release.protein.fa.gz";
    return $fasta;
}

has 'ests_file' => (
    is => 'ro',
    lazy_build => 1);

sub _build_ests_file {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $id      = $self->bioproject_id;
    my $fasta   = "$name.$id.$release.ests.fa.gz";
    return $fasta;
}


# Discover the name of the GFF file and its version.
has 'gff_file' => (
    is => 'rw',
    lazy_build => 1
);

sub _build_gff_file {
    my $self    = shift;
    my $name    = $self->symbolic_name;
    my $release = $self->release;	
    my $id      = $self->bioproject_id;
    my $gff = join("/",$self->release_dir,"$name.$id.$release.annotations.gff2.gz");
    if (-e $gff) {
	$self->gff_version('2');
    } else {
	$gff = join("/",$self->release_dir,"$name.$id.$release.annotations.gff3.gz");
	if (-e $gff) {
	    $self->gff_version('3');
	}
    }
    $self->log->logdie(uc($name) . ": couldn't find a suitable GFF file") unless $gff;
    return $gff;
}
        
has 'gff_version' => (
    isa     => 'Str',
    is      => 'rw',
    );


1;
