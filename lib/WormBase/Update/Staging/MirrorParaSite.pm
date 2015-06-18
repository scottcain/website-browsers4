package WormBase::Update::Staging::MirrorParaSite;

use Moose;
use Net::FTP::Recursive;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'mirror the ParaSite FTP site',
    );

  
sub run {
    my $self = shift;
    
    my $local_path  = $self->ftp_root;
    my $remote_path = $self->remote_ftp_root_parasite;
    my $remote_host = $self->remote_ftp_server_parasite;
    
    my $log = $self->log;    
    $self->log->info("mirroring parasite directory $remote_path to $local_path");
    
    # Via system(wget...)
#    if (0) {
	my $command = <<END;
mkdir -p $local_path
cd $local_path
# -r     recursive
# -N     don't download newer files
# -l 10  maximum depth
# -nH    omit the host from the local directory
# --cut-dirs=3    Is this the right amount when mirroring from root?
wget -r -N -nH -l 20 --cut-dirs=4 $remote_host/$remote_path
END
;
    my $result = system($command);
    if ($result != 0) { $self->log->logdie("mirroring the parasite FTP site failed") };
    $self->log->info("mirroring the parasite FTP site: done");
}




1;
