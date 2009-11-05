package Update::CreateDirectories;

use base 'Update';
use strict;

my @directories = qw/blast blat epcr ontology tiling_array interaction orthology position_matrix gene/;

# The symbolic name of this step
sub step { return 'create directories'; }

sub run {
    my $self = shift;
    
    my $release        = $self->release;
    
    my $support_db_dir = $self->support_dbs;
    $self->_make_dir($support_db_dir);
    $self->_make_dir("$support_db_dir/$release");
    
    foreach (@directories) {
	$self->_make_dir("$support_db_dir/$release/$_");
    }
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}


1;
