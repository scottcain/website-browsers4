package Update::MirrorAcedb;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'mirror new acedb release'; }

sub run {
    my $self = shift;
    $self->install_path($self->acedb_root .'/elegans_' . $self->release);
    $self->local_mirror_directory($self->acedb_root . '/tmp');
    
    $self->mirror_acedb;
    $self->untar_acedb;
    $self->customize_acedb;
    $self->update_symlink({path    => $self->acedb_root,
			 target  => 'elegans_' . $self->release,
			   symlink => 'elegans',
		       });
    my $fh = $self->master_log;
    print $fh $self->step . " Mirroring AceDB complete...\n";
}

sub mirror_acedb {
    my ($self) = @_;
    
    my $release   = $self->release;
    my $ftp_path  = $self->remote_ftp_path;    
    my $ftp_remote_dir = "$ftp_path/$release/acedb";
    
    $self->mirror_directory($ftp_remote_dir,$self->local_mirror_directory);
}

sub untar_acedb {
    my $self = shift;
    $self->logit->debug("untarring acedb");
    
    my $destination = $self->install_path;  
    my $source      = $self->local_mirror_directory;
    my $acedb_group = 'acedb';
    $self->_reset_dir($destination);
    system("chgrp $acedb_group $destination");
    system("chmod g+ws $destination");

    # Hack to account for different versions of gzip
    # May not be necessary to un/re gzip...
    # If script fails, try uncommenting the following two lines.
    # You'll need a fair amount of disk space.
#    system("gunzip $source/database*");
#    system("gzip $source/database*");

    chdir $destination;  
    foreach (<$source/database*.tar.gz>) {
	my $cmd = "gunzip -c $_ | tar xvf -"; # perl test.pl  >> tmp 2>&1
	system($cmd) && $self->logit->logdie("couldn't untar acedb files to $destination: $!");
    }

    system("chmod g+ws $destination/database");
    return;
}


sub customize_acedb {
    my $self = shift;
    $self->logit->debug("customizing acedb");
    my $release      = $self->release;
    my $release_id   = $self->release_id;
    my $source_wspec = $self->root       . "/wspec";
    my $target_wspec = $self->acedb_root . "/elegans_$release/wspec";
    
    system("chmod ug+rw $target_wspec/*.wrm") && $self->logit->warn("Problems encountered customizing acedb: $!");
    foreach (<${source_wspec}/*.wrm>) {
	system("cp $_ $target_wspec/.") && $self->logit->warn("Problems encountered customizing acedb: $!");
    }
}

1;
