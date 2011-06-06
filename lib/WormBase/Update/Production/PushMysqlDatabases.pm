package WormBase::Update::Production::PushMysqlDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'push mysql databases to production',
    );

has 'method' => (
    is       => 'rw',
    required => 1,
    );

sub run {
    my $self = shift;
    
    # get a list of nodes
    my ($nodes) = $self->local_mysql_database_nodes;

    $self->package_database() if ($self->method eq 'by_package');

#    $self->fix_permissions;

    foreach my $node (@$nodes) {
	# Three approaches:
	# 1. Rsync a tgz
	if ($self->method eq 'by_package') { $self->rsync_package($node); }

	# 2. Rsync individual databases one at a time.
	# Alternative approach to syncing tarballs.
	if ($self->method eq 'by_directory') { $self->rsync_single_release($node); }
    }
}


sub package_database {
    my $self        = shift;

    my $release     = $self->release;
    my $destination_dir = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    $self->_make_dir($destination_dir);

    my $source_root = $self->mysql_data_dir;
    my $filename     = "mysql_databases.$release";

    chdir($destination_dir);
    if (-e "$filename.tgz") { 
	$self->log->info("mysql dbs have already been packaged; returning") && return;
    }

    $self->log->info("creating tgz of mysql databases");
    
    # We change directory to the source root to package wormbase_WSXXX without leading directories.
    $self->system_call("tar -czf $filename.tgz -C $source_root '*$release'",
		       'packaging mysql database dir');
    $self->log->info("creating tgz of mysql databases: done");
    
    $self->create_md5($destination_dir,$filename);
}

sub rsync_package { 
    my ($self,$node) = @_;
    my $release   = $self->release;    
    my $source_dir      = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    my $destination_dir = $self->mysql_data_dir;
    my $database = "mysql_databases.$release";

    # Rsync it.
    $self->system_call("rsync --rsh=ssh -Cav $source_dir/$database.tgz $node:$destination_dir",
		       'rsyncing mysql package');

    # Unpack it.
    # This SHOULD be a tarbomb which is what I want. Verify.
    $self->system_call(qq/ssh $node "cd $destination_dir; tar xzf $database.tgz"/,
		       'unpacking mysql package');

    # Remove it.
    $self->system_call(qq/ssh $node "cd $destination_dir; rm -f $database.tgz"/,
		       'removing mysql package');

}


# Not really applicable. We sync mysql databases by version
# and it doesn't really make sense to keep the entire data dir
# in sync.
sub rsync_database_dir {
    my ($self,$node) = @_;
    my $root = $self->mysql_data_dir;
    $self->log->info("rsyncing all (unpacked) mysql databases to $node");
    
    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' --exclude '*TMD' $root/ $node:$root/",
		       'rsyncing mysql database directory');
    
    $self->log->info("rsyncing all (unpacked) mysql databases to $node");
}

# Probably makes the most sense for MySQL databases.
sub rsync_single_release {
    my ($self,$node) = @_;
    my $root = $self->mysql_data_dir;
    
    my $release = $self->release;
    my @updated_databases = glob("$root/*$release");
    
    foreach my $database (@updated_databases) {
	$self->log->info("rsyncing $database to $node");
	
	$self->system_call("rsync --rsh=ssh -Cav -z --exclude '*bak*' --exclude '*TMD' $database $node:$root/","rsyncing $database to $node");
#	$self->log->info("rsyncing $database to $node: done");
    }
}


# NOT DONE
# Create mysql dumps, rsync to nodes and load.
sub create_mysql_dumps {
    my ($self,$node) = @_;
    my $tmp_dir = $self->tmp_dir;

    my $release = $self->release;
    my $host    = $self->mysql_host;
    my $user    = $self->mysql_user;
    my $pass    = $self->mysql_pass;

    my $root = $self->mysql_data_dir;
    my @updated_databases = glob("$root/*$release");
    
    foreach my $database (@updated_databases) {
	
	$self->log->info("rsyncing $database to $node");
	
	$self->system_call("rsync --rsh=ssh -Cav -z --exclude '*bak*' --exclude '*TMD' $database $node:$root/","rsyncing $database to $node");
	$self->log->info("rsyncing $database to $node: done");
    }
}



sub fix_permissions { 
    my ($self,$node) = @_;
    my $root = $self->mysql_data_dir;
    my $release = $self->release;
    
    $self->system_call("cd $root; pwd; chmod -R 2775 *$release",
		       'fixing mysql permissions');
        
}




1;
