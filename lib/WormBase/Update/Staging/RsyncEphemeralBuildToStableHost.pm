package WormBase::Update::Staging::RsyncEphemeralBuildToStableHost;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'rsync a new build of WormBase to a stable host, typically development',
);

has 'target_host' => (
    is => 'rw',
    default => 'dev.wormbase.org'
    );

sub run {
    my $self    = shift;       
    my $release = $self->release;
    
    # The FTP directory
    $self->rsync_directory($self->ftp_root);   

    # /usr/local/wormbase/acedb/wormbase_$release
    $self->rsync_directory("/usr/local/wormbase/acedb/wormbase_$release");   

    # Website shared
    $self->rsync_directory("/usr/local/wormbase/website-shared-files");
    
    # The databases directory
    $self->rsync_directory("/usr/local/wormbase/databases");

    # What else?    
}


sub rsync_directory {
    my ($self,$directory) = @_;
    
    my $target_host  = $self->target_host;

    # We will use the INTERNAL IP of the FTP instance
    # to avoid data transfer charges.
    # This will ONLY work when run from within another EC2 instance!
    my @addresses = split(/\s/,`dig +short $host`);
    my $ip        = $addresses[2];

    $self->log->info("rsyncing $directory to $target_host at internal ip: $ip");
    
#	$self->system_call("rsync -Cavv --exclude httpd.conf --exclude cache --exclude sessions --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/shared/website/classic",'rsyncing classic site staging directory into production');
    $self->system_call("rsync -Cav $directory/ $ip:$directory","rsyncing $directory to $ip");
}


    
1;
