package WormBase::Update::Production::PushAcedb;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'push acedb to production',
    );

has 'method' => (
    is       => 'rw',
    required => 1,
    );


sub run {
    my $self = shift;
    
    # get a list of acedb nodes
    my ($nodes) = $self->local_acedb_nodes;

    $self->package_database() if ($self->method eq 'by_package');

    foreach my $node (@$nodes) {
	# Three approaches:
	# 1. Rsync a tgz
	if ($self->method eq 'by_package') { $self->rsync_package($node); }

	# 2. Keep the ENTIRE acedb directory in sync.
	# (current approach; run as cron)
	# Preferred alternative approach to syncing tarballs.
	if ($self->method eq 'all_directories') { $self->rsync_acedb_database_dir($node); };

	# 3. Rsync a single database directory
	if ($self->method eq 'by_directory') { $self->rsync_acedb_single_release($node) };
    }
}


sub package_acedb_database {
    my $self        = shift;

    my $release     = $self->release;
    my $destination_dir = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    $self->_make_dir($destination_dir);

    my $source_root = $self->acedb_root;
    my $database    = "wormbase_$release";
    my $filename    = "acedb_database.$release";

    chdir($destination_dir);
    if (-e "$database.tgz") { 
	$self->log->info("acedb has already been packaged; returning") && return;
    }

    $self->log->info("creating tgz of acedb $database");
    
    # We change directory to the source root to package wormbase_WSXXX without leading directories.
    $self->system_call("tar -czf $filename.tgz --exclude serverlog.wrm --exclude readlocks --exclude log.wrm -C $source_root $database",
		       'packaging acedb');
    $self->log->info("creating tgz of acedb $database: done");
    
    $self->create_md5($destination_dir,$filename);
}

sub rsync_package { 
    my ($self,$node) = @_;
    
    my $release         = $self->release;
    my $source_dir      = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    my $destination_dir = $self->acedb_root;
    my $database = "wormbase_$release";
    my $filename = "acedb_database.$release";

    # Rsync
    $self->system_call("rsync --rsh=ssh -Cav $source_dir/$filename.tgz $node:$destination_dir",
		       'rsyncing acedb package');

    # Unpack
    $self->system_call(qq/ssh $node "cd $destination_dir; tar xzf $filename.tgz"/,
		       'unpacking acedb package');

    # Rename
    $self->system_call(qq/ssh $node "cd $destination_dir; mv $filename $database"/,
		       'renaming acedb untarred package');

    # Remove
    $self->system_call(qq/ssh $node "cd $destination_dir; rm -f $filename.tgz"/,
		       'removing acedb package');

}


sub rsync_acedb_database_dir {
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    $self->log->info("rsyncing all (unpacked) acedb databases to $node");

    $self->system_call("rsync --rsh=ssh -Cav --include 'wormbase_*'  --exclude serverlog.wrm --exclude log.wrm --exclude readlocks --exclude '/*' $acedb_root/ $node:$acedb_root/",
	'rsyncing acedb database directory');
    
    $self->log->info("rsyncing all (unpacked) acedb databases to $node: done");
}

sub rsync_acedb_single_release {
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    my $database   = "$acedb_root/wormbase_" . $self->release;
    $self->log->info("rsyncing $database to $node");

    $self->system_call("rsync --rsh=ssh -Cav --exclude serverlog.wrm --exclude log.wrm --exclude readlocks $database $node:$acedb_root/","rsyncing $database to $node");
    $self->log->info("rsyncing $database to $node: done");
}



sub fix_permissions { 
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    
    $self->system_call("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks",
		       'fixing acedb permissions');
        
}




1;
