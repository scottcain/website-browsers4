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
    my $clustal_file = "wormpep" . $release_number . "_clw.sql.bz2";
    
    my $support_db_dir = $self->support_dbs;
    
    $self->_make_dir($support_db_dir);
    $self->_make_dir("$support_db_dir/$release");
    
    my $local_dir = $support_db_dir . "/clustal_staging";
    $self->_make_dir($local_dir);
    
    #$self->mirror_file($ftp_remote_dir, $clustal_file, $local_dir);
    
    my $check_file = "mirror_clustal.chk";
    
    ## unzip file
    my $unzip_cmd = "bunzip2 $local_dir/$clustal_file";
    #Update::system_call($unzip_cmd, $check_file);
    
    ## create mysql db
    my $mysql_data_dir = "/usr/local/mysql/data";
    my $create_db_cmd = "mkdir $mysql_data_dir/clustal_" . $release;
    Update::system_call($create_db_cmd, $check_file);
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
    
}


1;
