package WormBase::Update::Staging::MirrorNewRelease;

use Moose;
use Net::FTP::Recursive;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'mirror a new release from the Hinxton FTP site',
    );

  
sub run {
    my $self = shift;
    
    # Mirror a specific provided release, or discover
    # what the last one was and try to mirror the next;

    # This logic is handled upstream in the bin/mirror_new_release.pl.
    # That lets us establish the correct log files.
    my $release    = $self->release;
#    if ($release =~ /independent/) {   # hack.
#	$self->get_next_release();
#	$release = $self->release;
#    } 

    my $release_id = $self->release_id; 
    
    my $local_releases_path  = $self->ftp_releases_dir;
    my $remote_releases_path = $self->remote_ftp_releases_dir;

    my $log = $self->log;    
    $self->log->info("mirroring directory $remote_releases_path/$release to $local_releases_path/$release");

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

	if ($ftp->cwd("$remote_releases_path/$release")) {
	    # or $self->log->logwarn("cannot chdir to remote dir ($remote_releases_path/$release)") && return;	    
	    $self->_make_dir("$local_releases_path/$release");

	    chdir "$local_releases_path/$release"       or $self->log->logwarn("cannot chdir to local mirror directory: $local_releases_path/$release");

	    # Recursively download the NEXT release.  This saves having to check all the others.
	    my $r = $ftp->rget();  # MatchDirs => $release); 
	    $ftp->quit;
	}
    }
    
    $self->log->info("mirroring $release from Hinxton: done");


#    # Update symlinks on the FTP site.
#    if ($release) {
#	my $releases_dir = $self->ftp_releases_dir;
#	chdir($releases_dir);
#	$self->update_symlink({target => $release,
#			       symlink => 'current-development-release',
#			      });
#	
#	# Update symlinks to the development version
#	$self->update_ftp_site_symlinks({status => 'development'});
#    }
}




1;
