package WormBase::Update::Development::MirrorAcedb;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'unpack and customize acedb' );

sub run {
    my $self = shift;       
    $self->untar_acedb;
    $self->customize_acedb;
# We will do this at the end.
#    $self->update_symlink({path    => $self->acedb_root,
#			 target  => 'wormbase_' . $self->release,
#			   symlink => 'wormbase',
#		       });
}


sub untar_acedb {
    my $self = shift;
    $self->log->debug("untarring acedb");
    
    my $install = join("/",$self->acedb_path,$self->release);
    my $source  = join("/",$self->ftp_path,$self->release,'acedb');

    my $acedb_group $self->acedb_group;
    $self->_reset_dir($install);
    system("chgrp $acedb_group $install");
    system("chmod g+ws $install");

    chdir $install_path;  
    foreach (<$source/database*.tar.gz>) {
	my $cmd = "gunzip -c $_ | tar xvf -"; # perl test.pl  >> tmp 2>&1
	system($cmd) && $self->log->logdie("couldn't untar acedb files to $destination: $!");
    }

    system("chmod g+ws $install/database");
    return;
}


sub customize_acedb {
    my $self = shift;
    $self->log->debug("customizing acedb");
    my $release      = $self->release;
    my $release_id   = $self->release_id;
    my $source_wspec = $self->root_path  . "/website/clasic/wspec";
    my $target_wspec = $self->acedb_path . "/wormbase_$release/wspec";
    
    system("chmod ug+rw $target_wspec/*.wrm") && $self->log->warn("Problems encountered customizing acedb: $!");
    foreach (<${source_wspec}/*.wrm>) {
	system("cp $_ $target_wspec/.") && $self->log->warn("Problems encountered customizing acedb: $!");
    }
}

1;
