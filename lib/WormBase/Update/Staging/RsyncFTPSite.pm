package WormBase::Update::Staging::RsyncFTPSite;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'rsync the staged FTP site to the production FTP site',
);

sub run {
    my $self    = shift;       
    my $release = $self->release;
#    $self->rsync_ftp_directory();   
    $self->rsync_from_nfs_mount();
}


# Rsync the staging server's FTP directory
# to the production FTP directory (assuming that the
# two are running on different machines).
sub rsync_ftp_directory {
    my $self = shift;
    
    my $production_host  = $self->production_ftp_host;
    my $ftp_root         = $self->ftp_root;
    $self->log->info("rsyncing FTP site to $production_host");
    
#	$self->system_call("rsync -Cavv --exclude httpd.conf --exclude cache --exclude sessions --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/shared/website/classic",'rsyncing classic site staging directory into production');
    $self->system_call("rsync -Cav $ftp_root/ $production_host:$ftp_root",'rsyncing staging FTP site to the production host');
}


# Rsync from the NFS mount to (the other) FTP site NFS mount. Erm...
sub rsync_from_nfs_mount {
    my $self = shift;
    my $ftp_root         = $self->ftp_root;
    my $production_host  = $self->production_ftp_host;
    $self->log->info("rsyncing to FTP site to $production_host");
    
#	$self->system_call("rsync -Cavv --exclude httpd.conf --exclude cache --exclude sessions --exclude databases --exclude tmp/ --exclude extlib --exclude ace_images/ --exclude html/rss/ $app_root/ ${node}:$wormbase_root/shared/website/classic",'rsyncing classic site staging directory into production');
    $self->system_call("rsync -Cav /nfs/wormbase2/ftp/ /usr/local/wormbase/ftp/pub/wormbase",'rsyncing NFS mount staging FTP site to the production FTP site; once per day.');
    


1;
