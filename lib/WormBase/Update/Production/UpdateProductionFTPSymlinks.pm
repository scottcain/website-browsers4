package WormBase::Update::Staging::UpdateProductionFTPSymlinks;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'update symlinks on the production FTP site',
);

sub run {
    my $self = shift;       
    $self->update_ftp_site_symlinks();
}	    


# Change symlinks to point to the version being pushed out.
sub update_ftp_site_symlinks {
    my $self = shift;
    my $releases_dir = $self->ftp_releases_dir;
    my $species_dir  = $self->ftp_species_dir;
    
    # If provided, update symlinks on the FTP site
    # for that release.  Otherwise, walk through
    # the releases directory.
    my $release = $self->release;

    chdir($releases_dir);
    $self->update_symlink({target => $release,
			   symlink => 'current-www.wormbase.org-release',
			  });

    my @releases;
    if ($release) {
	@releases = glob("$releases_dir/$release") or die "$!";
    } else {
	@releases = glob("$releases_dir/*") or die "$!";
    }

    foreach my $release_path (@releases) {
	next unless $release_path =~ /.*WS\d\d.*/;    
	my @species = glob("$release_path/species/*");
	
	my ($release) = ($release_path =~ /.*(WS\d\d\d).*/);
	
	# Where should the release notes go?
	# chdir "$FTP_SPECIES_ROOT";
	
	foreach my $species_path (@species) {
	    next if $species_path =~ /README/;
	    
	    my ($species) = ($species_path =~ /.*\/(.*)/);
	    
	    # Create a symlink to each file in /species
	    opendir DIR,"$species_path" or die "Couldn't open the dir: $!";
	    while (my $file = readdir(DIR)) {
		
		# Create some directories. Probably already exist.
		chdir "$species_dir/$species";
		mkdir("gff");
		mkdir("annotation");
		mkdir("sequence");
		
		chdir "$species_dir/$species/sequence";
		mkdir("genomic");
		mkdir("transcripts");
		mkdir("protein");
		
		# GFF?
		chdir "$species_dir/$species";
		if ($file =~ /gff/) {
		    chdir("gff") or die "$!";
		    $self->update_symlink({target => "../../../releases/$release/species/$species/$file",
					   symlink => $file,
					   release => $release });
		} elsif ($file =~ /genomic|sequence/) {
		    chdir "$species_dir/$species/sequence/genomic" or die "$!";
		    $self->update_symlink({target  => "../../../../releases/$release/species/$species/$file",
					   symlink => $file,
					   release => $release });
		} elsif ($file =~ /transcripts/) {
		    chdir "$species_dir/$species/sequence/transcripts" or die "$! $species";
		    $self->update_symlink({target  => "../../../../releases/$release/species/$species/$file",
					   symlink => $file,
					   release => $release });
		} elsif ($file =~ /wormpep|protein/) {
		    chdir "$species_dir/$species/sequence/protein" or die "$!";
		    $self->update_symlink({target  => "../../../../releases/$release/species/$species/$file",
					   symlink => $file,
					   release => $release });
		    
		    # best_blast_hits isn't in the annotation/ folder
		} elsif ($file =~ /best_blast/) {
		    chdir "$species_dir/$species";
		    mkdir("annotation");
		    chdir("annotation");
		    mkdir("best_blast_hits");
		    chdir("best_blast_hits");
		    $self->update_symlink({target  => "../../../../releases/$release/species/$species/$file",
					   symlink => $file,
					   release => $release });
		} else { }
	    }
	    
	    # Annotations, but only those with the standard format.
#	chdir "$FTP_SPECIES_ROOT/$species";
	    opendir DIR,"$species_path/annotation" or next;
	    while (my $file = readdir(DIR)) {
		next unless $file =~ /^$species/;
		chdir "$species_dir/$species";
		
		mkdir("annotation");
		chdir("annotation");
		
		my ($description) = ($file =~ /$species\.WS\d\d\d\.(.*?)\..*/);
		mkdir($description);
		chdir($description);
		$self->update_symlink({target  => "../../../../releases/$release/species/$species/annotation/$file",
				       symlink => $file,
				       release => $release });
	    }
	}
    }
}


1;
