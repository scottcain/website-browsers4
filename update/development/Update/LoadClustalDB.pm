package Update::LoadClustalDB;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'loading clustal database'; }

sub run {
    my $self = shift;    
    my $release   = $self->release;
    my $ftp_path  = $self->remote_ftp_path;    

    my $clustal_file = $self->clustal_file;

    my $ftp_remote_dir = "$ftp_path/$release/$clustal_file.bz2";
    
    my $support_db_dir = $self->support_dbs;
    $self->_make_dir($support_db_dir);
    $self->_make_dir("$support_db_dir/$release");
    
    # TAKE A LOOK AT mirror_file instead of mirror_directory...

    my $local_dir = $self->mirror_dir;
    $self->_make_dir($local_dir);
    
    $self->mirror_directory($ftp_remote_dir,$local_dir);


    # Unpack and load

    # Cleanup
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}


1;
