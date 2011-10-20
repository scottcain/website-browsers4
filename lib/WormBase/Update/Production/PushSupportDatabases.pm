package WormBase::Update::Production::PushSupportDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'push support databases to production',
    );

has 'method' => (
    is       => 'rw',
    required => 1,
    );

sub run {
    my $self = shift;
   
    if ($self->method eq 'by_package') { $self->package_database(); }

    # Sync the support databases dir to our local NFS mount.
#    $self->rsync_database_dir_to_nfs_mount();

    # OR each node gets their own.
    my ($local_nodes)  = $self->local_support_database_nodes; 
    my ($remote_nodes) = $self->remote_support_database_nodes;
    foreach my $node (@$local_nodes,@$remote_nodes) {
#    foreach my $node (@$remote_nodes) {
	# Three approaches:
	# 1. Rsync a tgz
	if ($self->method eq 'by_package') { $self->rsync_package($node); }
	
	# 2. Keep the whole directory in sync.
	# (current approach; run as cron)
	# Preferred alternative approach to syncing tarballs.
	if ($self->method eq 'all_directories') { $self->rsync_database_dir($node); }
	
	# 3. Rsync a single database directory
	if ($self->method eq 'by_directory') { $self->rsync_single_release($node); }
    }
}


sub package_database {
    my $self        = shift;
    
    my $release     = $self->release;
    my $destination_dir = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    $self->_make_dir($destination_dir);
    
    my $source_root = $self->support_databases_dir;    
    my $filename    = "support_databases.$release";
    
    chdir($destination_dir);
    if (-e "$filename.tgz") { 
	$self->log->info("support dbs have already been packaged; returning") && return;
    }
    
    $self->log->info("creating tgz of support databases $filename");
    
    # We change directory to the source root to package wormbase_WSXXX without leading directories.
    $self->system_call("tar -czf $filename.tgz -C $source_root $release",
		       'packaging support database dir');
    $self->log->info("creating tgz of support databases $filename: done");
    
    $self->create_md5($destination_dir,$filename);
}


sub rsync_package { 
    my ($self,$node) = @_;
    my $release   = $self->release;
    my $source_dir      = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    my $destination_dir = $self->support_databases_dir;
    my $database        = "support_databases.$release";
    
    # Rsync it.
    $self->system_call("rsync --rsh=ssh -Cav $source_dir/$database.tgz $node:$destination_dir",
		       'rsyncing support databases package');

    # Unpack it.
    $self->system_call(qq/ssh $node "cd $destination_dir; tar xzf $database.tgz"/,
		       'unpacking support databases package');

    # Rename it.
    $self->system_call(qq/ssh $node "cd $destination_dir; mv $database $release"/,
		       'moving the support databases package');
    
    # Remove it.
    $self->system_call(qq/ssh $node "cd $destination_dir; rm -f $database.tgz"/,
		       'removing the support databases package');

    
}



# Keep the entire support databases directory in sync.
sub rsync_database_dir_to_nfs_mount {
    my $self = shift;

    my $wormbase_root = $self->wormbase_root;
    my $root          = $self->support_databases_dir;

    my $nfs_server    = $self->local_nfs_server;
    my $nfs_root      = $self->local_nfs_root;
    $self->log->info("rsyncing all (unpacked) support databases to nfs mount: $nfs_server");

    $self->system_call("rsync --rsh=ssh -Cav -z --exclude '*bak*' $root $nfs_server:$nfs_root/",
		       "rsyncing support $nfs_server:$nfs_root");

    $self->log->info("rsyncing all (unpacked) support databases to nfs mount: $nfs_server: done");

    $self->log->info("rsyncing other support files to nfs mount: $nfs_server");

    # There are a few other things that we need to keep in sync, too.
    # Keep the shared directory in sync.
    $self->system_call("rsync -Ca $wormbase_root/shared/website-shared-files $nfs_server:$nfs_root/",'rsyncing website shared files');
    
    # Send the admin module over. Or could just do a checkout...
#    $self->system_call("rsync -Ca /home/tharris/projects/wormbase/website-admin/ $nfs_server:$nfs_root/admin",'rsyncing website admin module');

    $self->log->info("rsyncing other support files to nfs mount: $nfs_server: done");
}



# Keep the entire support databases directory in sync.
sub rsync_database_dir {
    my ($self,$node) = @_;
    my $root = $self->support_databases_dir;
    $self->log->info("rsyncing all (unpacked) support databases to $node");

    $self->system_call("rsync --rsh=ssh -Cav -z --exclude '*bak*' $root/ $node:$root/",
	'rsyncing support database directory');

    $self->log->info("rsyncing all (unpacked) support databases to $node");
}

sub rsync_single_release {
    my ($self,$node) = @_;
    my $root = $self->support_databases_dir;
    my $database   = "$root/" . $self->release;
    $self->log->info("rsyncing $database to $node");

    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' $database $node:$root/","rsyncing $database to $node");

    # There are a few other things that we need to keep in sync, too.
    $self->system_call("rsync -Ca $wormbase_root/website-shared-files $node:/usr/local/wormbase/",'rsyncing website shared files');
    
    # Send the admin module over. Or could just do a checkout...
    $self->system_call("rsync -Ca /home/tharris/projects/wormbase/website-admin $node:/usr/local/wormbase/",'rsyncing website admin module');



    $self->log->info("rsyncing $database to $node: done");
}


# Not necessary here.
sub fix_permissions { 
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    
    $self->system_call("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks",
		       'fixing acedb permissions');
        
}




1;
