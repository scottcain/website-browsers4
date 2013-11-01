package WormBase::Update::Staging::PurgeOldDatabasesFromRDS;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'purge old releases',
    );

sub run {
    my $self = shift;
    
    my $release = $self->release;

    $self->log->info("purging $release databases from RDS...");


    my ($species) = $self->wormbase_managed_species;
    foreach my $name (sort { $a cmp $b } @$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	

	my $mysql_host = $self->rds_host;   # This should be a little more intelligent/dynamic.
	my $mysql_pass = $self->rds_pass;   # access controlled by security group
	my $mysql_user = $self->rds_user;

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {
	    my $id = $bioproject->bioproject_id;
	    my $db = join('_',$name,$id,$release);
	    $self->log->info("deleting $db from $mysql_host...");
	    $self->log->info("\tmysql -u $mysql_user -h $mysql_host -p$mysql_pass -e 'drop database $db'");
	    $self->system_call("mysql -u $mysql_user -h $mysql_host -p$mysql_pass -e 'drop database $db'");
	}	    
    }
}

1;
