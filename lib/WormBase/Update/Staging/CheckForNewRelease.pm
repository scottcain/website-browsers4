package WormBase::Update::Staging::CheckForNewRelease;

use Moose;
use Net::FTP::Recursive;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'checking for a new release from the Hinxton FTP site',
    );

  

    


sub run {
    my $self = shift;
    
    # Mirror a specific provided release, or discover
    # what the last one was and try to mirror the next;

    # This logic is handled upstream in the bin/mirror_new_release.pl.
    # That lets us establish the correct log files.
    my $release    = $self->release;
    my $release_id = $self->release_id; 
    
    my $local_releases_path  = $self->ftp_releases_dir;
    my $remote_releases_path = $self->remote_ftp_releases_dir;

    my $log = $self->log;    
    $self->log->info("$release is the next scheduled WB release; checking to see if it is on Hinxton FTP site yet");

    my $ftp = $self->connect_to_ftp;
    
    if ($ftp->cwd("$remote_releases_path/$release")) {
	$self->log->info("   --> It is!");

	# Need to set a flag so I can trigger downstream steps. ENV? File?       
	$ENV{WORMBASE_RELEASE} = $release;
    }

    $ftp->quit;    
    $self->log->info("checking for a new release ($release) from Hinxton: done");
}




1;
