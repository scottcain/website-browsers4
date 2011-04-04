package Update::MirrorWebData;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'mirror mysql gff databases'; }

sub run {
    my $self = shift;    
    my $release   = $self->release;
    my $ftp_path  = $self->remote_ftp_path;    
    my $ftp_remote_dir = "$ftp_path/web_data/gff_dbs";
    
    my $support_db_dir = $self->support_dbs;
    #$self->_make_dir($support_db_dir);
    #$self->_make_dir("$support_db_dir/$release");
    
    my $local_dir = $support_db_dir . "/web_data/mysql_tgzs";
    $self->_make_dir($local_dir);
    
    $self->mirror_directory($ftp_remote_dir,$local_dir);
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}


1;
