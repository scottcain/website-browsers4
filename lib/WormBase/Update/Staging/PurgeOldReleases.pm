package WormBase::Update::Staging::PurgeOldReleases;

use lib "/usr/local/wormbase/website/tharris/extlib";
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
    my $staging_host = $self->staging_host;

    # get a list of acedb nodes
    my ($acedb_nodes) = $self->production_acedb_nodes;
    push @$acedb_nodes,$staging_host;
    foreach my $node (@$acedb_nodes) {
	$self->log->info("purging acedb $release from $node");
	$self->system_call("ssh $node rm -rf /usr/local/wormbase/acedb/wormbase_$release",
			   "ssh $node rm -rf /usr/local/wormbase/acedb/wormbase_$release");
	
    }
    
    my ($local_nodes)  = $self->production_support_nodes; 
    push @$local_nodes,$staging_host;
    foreach my $node (@$local_nodes) {
	$self->log->info("purging support databases for $release from $node");
	$self->system_call("ssh $node rm -rf /usr/local/wormbase/databases/$release",
			   "ssh $node rm -rf /usr/local/wormbase/databases/$release");
    }
    
    # get a list of mysql nodes
    my ($mysql_nodes) = $self->production_mysql_nodes;
    push @$mysql_nodes,$staging_host;
    foreach my $node (@$mysql_nodes) {    
	$self->log->info("purging mysql databases for $release from $node");
	$self->system_call("ssh $node rm -rf /usr/local/mysql/data/*$release",
			   "ssh $node rm -rf /usr/local/mysql/data/*$release");
    }
    

# Finally, remove this release from the staging FTP site, too.    
    $self->system_call("ssh $staging_host rm -rf /usr/local/ftp/pub/wormbase/releases/$release",
		       "ssh $staging_host rm -rf /usr/local/ftp/pub/wormbase/releases/$release");    
    
}



1;
