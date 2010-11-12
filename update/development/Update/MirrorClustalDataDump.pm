package Update::MirrorClustalDataDump;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'mirror clustal data dump'; }

sub run {
    my $self = shift;    
    my $release   = $self->release;
    my $ftp_path  = $self->remote_ftp_path;    
    my $ftp_remote_dir = "$ftp_path/$release/COMPARATIVE_ANALYSIS";
    my ($disc, $release_number) = split "S", $release;
    my $remote_file = "wormpep" . $release_number . "_clw.sql.bz2";
    
    my $support_db_dir = $self->support_dbs;
    
    $self->_make_dir($support_db_dir);
    $self->_make_dir("$support_db_dir/$release");
    
    my $local_dir = $support_db_dir . "/clustal_staging";
    $self->_make_dir($local_dir);
    
    $self->mirror_file($ftp_remote_dir, $remote_file, $local_dir);
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}


1;
