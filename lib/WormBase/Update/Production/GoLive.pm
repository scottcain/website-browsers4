package WormBase::Update::Production::GoLive;

use Moose;
use Net::OpenSSH;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'go live with a new production release of WormBase',
);

sub run {
    my $self = shift;       
    my $release = $self->release;

    $self->update_acedb_symlinks();
    $self->update_mysql_symlinks();
    $self->update_ftp_site_symlinks();
}

sub update_acedb_symlinks { 
    my $self = shift;
    $self->log->info("adjusting symlinks on acedb production servers");

    my ($local_nodes)  = $self->local_acedb_nodes;
    my ($remote_nodes) = $self->remote_acedb_nodes;

    my $acedb_root = $self->acedb_root;
    my $release    = $self->release;

    my $manager = $self->production_manager;

    foreach my $node (@$local_nodes,@$remote_nodes) {
	$self->log->debug("adjusting acedb symlink on $node");

	my $ssh = Net::OpenSSH->new("$manager\@$node");
	$ssh->error and die "Can't ssh to $manager\@$node: " . $ssh->error;	
	$ssh->system("cd $acedb_root ; rm wormbase ; ln -s wormbase_$release wormbase") or
	    $self->log->logdie("remote command updating the acedb symlink failed " . $ssh->error);
	
    }
}

sub update_mysql_symlinks { 
    my $self = shift;
    $self->log->info("adjusting symlinks on mysql production servers");
    my ($local_nodes)  = $self->local_mysql_database_nodes;
    my ($remote_nodes) = $self->remote_mysql_database_nodes;

    my $mysql_data_dir = $self->mysql_data_dir;
    my $release        = $self->release;
    my $manager        = $self->production_manager;
    foreach my $node (@$local_nodes,@$remote_nodes) {
	$self->log->debug("adjusting mysql symlinks on $node");
	my ($species) = $self->wormbase_managed_species;  # Will be species updated this release.
	foreach my $name (@$species) {
	    my $ssh = Net::OpenSSH->new("$manager\@$node");
	    $ssh->error and die "Can't ssh to $manager\@$node: " . $ssh->error;	
	    $ssh->system("cd $mysql_data_dir ; rm $name ; ln -s $name_$release $name") or
		$self->log->logdie("remote command updating the mysql symlink failed " . $ssh->error);
	}
    }
}


# Change symlinks to point to the version being pushed out.
sub update_ftp_site_symlinks {
    my $self = shift;
    my $releases_dir = $self->ftp_releases_dir;
    my $species_dir  = $self->ftp_species_dir;
    
    chdir($releases_dir);
    $self->update_symlink({target => $release,
			   symlink => 'current-www.wormbase.org-release',
			  });

    # If provided, update symlinks on the FTP site
    # for that release.  Otherwise, walk through
    # the releases directory.
    my $release = $self->release;

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
