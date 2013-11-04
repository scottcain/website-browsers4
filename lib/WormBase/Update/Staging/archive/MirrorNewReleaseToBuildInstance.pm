package WormBase::Update::Staging::MirrorNewReleaseToBuildInstance;

use Moose;
use Net::FTP::Recursive;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'mirror a new release from the WormBase FTP site to the build instance',
    );

  
sub run {
    my $self = shift;
    my $release    = $self->release;
    my $release_id = $self->release_id; 
    
    # paths are the same locally and remotely  
    my $local_path  = $self->ftp_releases_dir;
    my $remote_path = $self->ftp_releases_dir . "/$release";

    my $log = $self->log;    
    $self->log->info("mirroring directory $remote_path to $local_path on ephemeral storage");

    $self->log->info("rsyncing release to build instance");
    $self->system_call("rsync --rsh=ssh -Cav $node:$remote_path $local_path/","rsyncing $database to $node");
    $self->log->info("rsyncing $database to $node: done");
}

1;
