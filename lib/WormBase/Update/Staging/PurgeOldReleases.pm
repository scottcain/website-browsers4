package WormBase::Update::Staging::PurgeOldReleases;

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
    my $target = $self->target;
       
    $self->log->info("purging acedb $release ...");
    $self->system_call("rm -rf /usr/local/wormbase/acedb/wormbase_$release");

    $self->log->info("purging support databases for $release ...");
    $self->system_call("rm -rf /usr/local/wormbase/databases/$release");

    # TO DO: This actually needs to be a list of databases to DROP
    # We should also drop databases from RDS.
    $self->log->info("purging mysql databases for $release from $node");
    $self->system_call("");        

}


1;
