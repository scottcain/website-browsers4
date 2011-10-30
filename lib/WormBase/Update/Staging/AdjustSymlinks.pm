package WormBase::Update::Staging::GoLive;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'go live with a new release of WormBase',
);

sub run {
    my $self = shift;       
    my $release = $self->release;    
    my $target  = $self->target;  # production, development, staging, mirror
    
    ###################################
    # Acedb
    my ($acedb_nodes) = $self->target_nodes('acedb');	
    foreach my $node (@$acedb_nodes) {
	$self->update_acedb_symlink($node);
    }
    
    ###################################
    # MySQL
    my ($acedb_nodes) = $self->target_nodes('mysql');	
    foreach my $node (@$mysql_nodes) {
	$self->update_mysql_symlinks($node);
    }
}	    


sub update_acedb_symlink {
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    my $release = $self->release;

    $self->log->debug("adjusting acedb symlink on $node");
    
    my $ssh = $self->ssh($node);
    $ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
    $ssh->system("cd $acedb_root ; rm wormbase ; ln -s wormbase_$release wormbase") or
	$self->log->logdie("remote command updating the acedb symlink failed " . $ssh->error);
}


sub update_mysql_symlinks {
    my $self = shift;
    $self->log->debug("adjusting mysql symlinks on $node");
    
    # Get a list of all species updated this release.
    my ($species) = $self->wormbase_managed_species;
    push @$species,'clustal';   # clustal database, too.

    my $mysql_data_dir = $self->mysql_data_dir;
    my $release        = $self->release;
    my $manager        = $self->production_manager;

    foreach my $name (@$species) {
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);	
	$ssh->system("cd $mysql_data_dir ; rm $name ; ln -s ${name}_$release $name") or
	    $self->log->logdie("remote command updating the mysql symlink failed " . $ssh->error);
    }
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
