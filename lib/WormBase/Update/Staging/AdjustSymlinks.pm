package WormBase::Update::Staging::AdjustSymlinks;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'adjust acedb and mysql symlinks for a new release of WormBase',
);

sub run {
    my $self = shift;       
    my $release = $self->release;    
    my $target  = $self->target;  # production, development, staging, mirror, new
    
    ###################################
    # Acedb
    my ($acedb_nodes) = $self->target_nodes('acedb');	
    foreach my $node (@$acedb_nodes) {
	$self->update_acedb_symlink($node);
    }
    
    ###################################
    # MySQL
    my ($mysql_nodes) = $self->target_nodes('mysql');	
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
    my ($self,$node) = @_;
    $self->log->debug("adjusting mysql symlinks on $node");
    
    # Get a list of all species updated this release.
    my ($species) = $self->wormbase_managed_species;
    
    my $mysql_data_dir = $self->mysql_data_dir;
    my $release        = $self->release;
    my $manager        = $self->production_manager;
    
    foreach my $name (@$species) {

	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {

	    unless ($bioproject->has_been_updated) {
		$self->log->info(  "Skipping $name; it was not updated during this release cycle");
		next;
	    }
	    
	    my $id = $bioproject->bioproject_id;
	    $self->log->info("   Adjusting the MySQL symlink for bioproject: $id");

	    my $db_name = $bioproject->mysql_db_name;
	    
	    my $ssh = $self->ssh($node);
	    $ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);
	    $ssh->system("cd $mysql_data_dir ; rm $name ; ln -s ${db_name} $name") or
		$self->log->logdie("remote command updating the mysql symlink failed " . $ssh->error);
	}
    }


    # Update non-species related DBs
    my %dbs = ( clustal => "clustal_$release" );
    foreach my $name (keys %dbs) {
	my $db_name = $dbs{$name};
	$self->log->info("   Adjusting the MySQL symlink for the clustal database");
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);
	$ssh->system("cd $mysql_data_dir ; rm $name ; ln -s ${db_name} $name") or
	    $self->log->logdie("remote command updating the mysql symlink failed " . $ssh->error);
    }
}



1;
