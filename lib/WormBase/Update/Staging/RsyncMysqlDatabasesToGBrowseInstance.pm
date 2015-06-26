package WormBase::Update::Staging::RsyncMysqlDatabasesToGBrowseInstance;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'rsync mysql databases to the stable gbrowse instance',
);

has 'desired_species' => (
    is => 'ro',
    );

has 'target_host' => (
    is => 'rw',
    default => 'gbrowse.wormbase.org',
    );

sub run {
    my $self    = shift;       
    my $release = $self->release;
    my $desired_species = $self->desired_species;


    my $species = [];
    if ($desired_species) {
	push @$species,$desired_species;      
    } else {
	($species) = $self->wormbase_managed_species;
    }

    foreach my $name (sort { $a cmp $b } @$species) {
	
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	
	
	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {
	    my $id = $bioproject->bioproject_id;

	    my $database = join('_',$name,$id,$release);
	    $self->rsync_directory("/var/lib/mysql/$database");
	}
    }
}


sub rsync_directory {
    my ($self,$directory) = @_;
    
    my $target_host  = $self->target_host;

    my @addresses = split(/\s/,`dig +short $target_host`);
    my $ip        = $addresses[2];
    $ip ||= $addresses[0];

    $self->log->info("rsyncing $directory to $target_host at internal ip: $ip");
    
#	$self->system_call("rsync -Cavv --exclude httpd.conf --exclude cache --exclude sessions --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/shared/website/classic",'rsyncing classic site staging directory into production');
#    $self->system_call("rsync --list-only -Cav $directory/ $ip:$directory","rsyncing $directory to $ip");
    $self->system_call("rsync -Cav $directory/ $ip:$directory","rsyncing $directory to $ip");
}


    
1;
