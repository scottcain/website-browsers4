package WormBase::Update::Staging::MirrorNewRelease;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use Net::FTP::Recursive;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'mirror a new release from the Hinxton FTP site',
    );

  
has 'connect_to_ftp' => (
    is         => 'ro',
    lazy_build => 1,
    builder    => '_connect_to_ftp',
    );

sub _build_connect_to_ftp {
    my $self = shift;

    my $contact_email = $self->contact_email;
    my $ftp_server    = $self->remote_ftp_server;

    my $ftp = Net::FTP::Recursive->new($ftp_server,
				       Debug => 0,
				       Passive => 1) or $self->log->logdie("can't instantiate Net::FTP object");

    $ftp->login('anonymous', $contact_email) or $self->log->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->log->warn("couldn't switch to binary mode for FTP");    
    return $ftp;
}
    


sub run {
    my $self = shift;
    
    # Mirror a specific provided release, or discover
    # what the last one was and try to mirror the next;

    # This logic is handled upstream in the bin/mirror_new_release.pl.
    # That lets us establish the correct log files.

    my $release    = $self->release;
    unless ($release) {
	$self->get_next_release();
	$release = $self->release;
    }
    my $release_id = $self->release_id; 

    $self->log->debug("mirroring $release from Hinxton");    
    
    my $local_releases_path  = $self->ftp_releases_dir;
    my $remote_releases_path = $self->remote_ftp_releases_dir;
    
    $self->log->debug("mirroring directory $remote_releases_path/$release to $local_releases_path/$release");

    # Via system(wget...)
    if (0) {
	my $command = <<END;
cd $local_releases_path
# -r     recursive
# -N     don't download newer files
# -l 10  maximum depth
# -nH    omit the host from the local directory
# --cut-dirs=3    Is this the right amount when mirroring from root?
wget -r -N -nH -l 20 --cut-dirs=3 ftp://ftp.sanger.ac.uk/pub2/wormbase/releases/$release
END
;
	my $result = system($command);
	if ($result != 0) { $self->log->logdie("mirroring $release from hinxton failed") };
	
    } else {
	
	# Via Net::FTP
	my $ftp = $self->connect_to_ftp;
	chdir $local_releases_path       or $self->log->logdie("cannot chdir to local mirror directory: $local_releases_path");
	$ftp->cwd($remote_releases_path) or $self->log->error("cannot chdir to remote dir ($remote_releases_path)") && return;
	
	# Recursively download the NEXT release.  This saves having to check all the others.
	my $r = $ftp->rget(MatchDirs => $release); 
	$ftp->quit;
    }
    
    $self->log->debug("end: mirroring $release from Hinxton complete");
}




1;
