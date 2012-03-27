package WormBase::Update::Production::PushSoftware;

# This is a moudle used to push only the OLD
# website into production.

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'deploying a new version of the webapp',
);


########################################################

sub run {
    my $self = shift;           
    $self->rsync_staging_directory;    
}



sub rsync_staging_directory {
    my $self = shift;

    $self->log->info('deploying software');
    my ($local_nodes)  = $self->local_web_nodes;
    my ($remote_nodes) = $self->remote_web_nodes;

    my $wormbase_root = $self->wormbase_root;
    my $app_root      = $self->wormbase_root . "/website/classic";
    
    my $nfs_server    = $self->local_nfs_server;
    my $nfs_root      = $self->local_nfs_root;

    foreach my $node (@$local_nodes,@$remote_nodes) {
	$self->log->info("rsync staging directory to $node");
#	my $ssh = $self->ssh($node);
#	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);

	# Rsync the staging directory.
#	$self->system_call("rsync -Cav --exclude httpd.conf --exclude cache --exclude sessions --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/website/classic",'rsyncing classic site staging directory into production');
	
	$self->system_call("rsync -Cav --exclude httpd.conf --exclude cache --exclude sessions --exclude html/session/ --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/website/classic",'rsyncing classic site staging directory into production');
    }
}


1;
