package WormBase::Update::Staging::PushStagedReleaseToNodes;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'push a staged release to specific nodes -- development OR production',
);

sub run {
    my $self = shift;       
    my $release = $self->release;
    my $target  = $self->target;
    
    if ($release) {

	###################################
	# Acedb
	my ($acedb_nodes) = $self->target_nodes('acedb');
	# $self->package_acedb() if ($self->method eq 'by_package');
	foreach my $node (@$acedb_nodes) {
	    $self->rsync_acedb_to_target_node($node);
	    # Other approaches
	    # $self->rsync_acedb_database_dir($node);
	    # $self->rsync_acedb_package($node);
	    $self->fix_acedb_permissions($node);
	}


	###################################
	# MySQL
	my ($mysql_nodes) = $self->target_nodes('mysql');
	# $self->package_mysql() if ($self->method eq 'by_package');
	foreach my $node (@$mysql_nodes) {
	    $self->rsync_mysql_to_target_node($node);
	    # Other approaches
	    # $self->rsync_mysql_database_dir($node);
	    # $self->rsync_mysql_package($node);
	    $self->fix_mysql_permissions($node);
	}
	

	###################################
	# Support
	my ($db_nodes) = $self->target_nodes('support');
	foreach my $node (@$db_nodes) {
	    # $self->package_support_databases() if ($self->method eq 'by_package');
	    $self->rsync_support_dbs_to_target_node($node);
	    # Other approaches
	    # $self->rsync_support_dbs_dir_to_nfs_mount($node);
	    # $self->rsync_support_dbs_dir($node);
	    # $self->rsync_support_dbs_package($node);
	}
	
    }
}



############################################
#
#   ACEDB
#
############################################

sub package_acedb {
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

# Straight up rsync
sub rsync_acedb_to_target_node {
    my ($self,$node) = @_;
    
    my $acedb_root = $self->acedb_root;
    my $database   = "$acedb_root/wormbase_" . $self->release;
    $self->log->info("rsyncing $database to $node");
    
    $self->system_call("rsync --rsh=ssh -Cavv --exclude serverlog.wrm --exclude log.wrm --exclude readlocks $database $node:$acedb_root/","rsyncing $database to $node");
    $self->log->info("rsyncing $database to $node: done");
    
#    $self->system_call("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks",
#		       'fixing acedb permissions');
}

sub rsync_acedb_package { 
    my ($self,$node) = @_;
    
    my $release         = $self->release;
    my $source_dir      = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    my $destination_dir = $self->acedb_root;
    my $database = "wormbase_$release";
    my $filename = "acedb_database.$release";

    # Rsync
    $self->system_call("rsync --rsh=ssh -Cav $source_dir/$filename.tgz $node:$destination_dir",
		       'rsyncing acedb package');

    my $ssh = $self->ssh($node);
    
    # Unpack
    $ssh->system("cd $destination_dir; tar xzf $filename.tgz") or $self->log->logdie("Couldn't unpack acedb on $node: " . $ssh->error);

    # Rename
    $ssh->system("cd $destination_dir; mv $filename $database") or $self->log->logdie("renaming acedb untarred package on $node: " . $ssh->error);

    # Remove
    $ssh->system("cd $destination_dir; rm -f $filename.tgz") or $self->log->logdie("removing acedb package failed: $node" . $ssh->error);

}

sub rsync_acedb_database_dir {
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    $self->log->info("rsyncing all (unpacked) acedb databases to $node");

    $self->system_call("rsync --rsh=ssh -Cav --include 'wormbase_*'  --exclude serverlog.wrm --exclude log.wrm --exclude readlocks --exclude '/*' $acedb_root/ $node:$acedb_root/",
	'rsyncing acedb database directory');
    
    $self->log->info("rsyncing all (unpacked) acedb databases to $node: done");
}


sub fix_acedb_permissions { 
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    
    $self->system_call("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks",
		       'fixing acedb permissions');
        
}




############################################
#
#   MYSQL
#
############################################

sub package_mysql {
    my $self        = shift;

    my $release     = $self->release;
    my $destination_dir = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    $self->_make_dir($destination_dir);

    my $source_root = $self->mysql_data_dir;
    my $filename     = "mysql_databases.$release";

    chdir($source_root);
    if (-e "$destination_dir/$filename.tgz") { 
	$self->log->info("mysql dbs have already been packaged; returning") && return;
    }

    $self->log->info("creating tgz of mysql databases");
    
    # We change directory to the source root to package wormbase_WSXXX without leading directories.
    $self->system_call("tar -czf $destination_dir/$filename.tgz  `find *$release`",
		       'packaging mysql database dir');
    $self->log->info("creating tgz of mysql databases: done");
    
    $self->create_md5($destination_dir,$filename);
}





# Rsync acedb to our development servers
sub rsync_mysql_to_target_node {
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


sub rsync_mysql_package { 
    my ($self,$node) = @_;
    my $release   = $self->release;    
    my $source_dir      = join('/',$self->ftp_database_tarballs_dir,$release,'packaged_databases');
    my $destination_dir = $self->mysql_data_dir;
    my $database = "mysql_databases.$release";

    # Rsync it.
    $self->system_call("rsync --rsh=ssh -Cav $source_dir/$database.tgz $node:$destination_dir",
		       'rsyncing mysql package');

    # Unpack it.
    my $ssh = $self->ssh($node);
    $ssh->system("cd $destination_dir ; tar xzf $database.tgz") or
	$self->log->logdie("unpacking the mysql package failed: " . $ssh->error);
    
    # Remove it.
    $ssh->system("cd $destination_dir ; rm -f $database.tgz") or
	$self->log->logdie("removing the database package failed: " . $ssh->error);
}


# Not really applicable. We sync mysql databases by version
# and it doesn't really make sense to keep the entire data dir
# in sync.
sub rsync_mysql_database_dir {
    my ($self,$node) = @_;
    my $root = $self->mysql_data_dir;
    $self->log->info("rsyncing all (unpacked) mysql databases to $node");
    
    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' --exclude '*TMD' $root/ $node:$root/",
		       'rsyncing mysql database directory');
    
    $self->log->info("rsyncing all (unpacked) mysql databases to $node");
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



sub fix_mysql_permissions { 
    my ($self,$node) = @_;
    my $root = $self->mysql_data_dir;
    my $release = $self->release;
    
    $self->system_call("cd $root; pwd; chmod -R 2775 *$release",
		       'fixing mysql permissions');
        
}



############################################
#
#   SUPPORT DBS
#
############################################

sub package_support_databases {
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

# Rsync a single release directory
sub rsync_support_dbs_to_target_node {
    my ($self,$node) = @_;    
    
    my $root = $self->support_databases_dir;
    my $database   = "$root/" . $self->release;
    
    $self->log->info("rsyncing $database to $node");
    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' $database $node:$root/","rsyncing $database to $node");
    
    my $wormbase_root = $self->wormbase_root;
    
    # There are a few other things that we need to keep in sync, too.
    $self->system_call("rsync -Cavv $wormbase_root/website-shared-files $node:/usr/local/wormbase/",'rsyncing website shared files');
    
    # Send the admin module over. Or could just do a checkout...
#    $self->system_call("rsync -Ca /home/tharris/projects/wormbase/website-admin $node:/usr/local/wormbase/",'rsyncing website admin module');
    
    $self->log->info("rsyncing $database to $node: done");
}


sub rsync_support_dbs_package { 
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
    $self->system_call("rsync -Cavv $wormbase_root/website-shared-files $nfs_server:$nfs_root/",'rsyncing website shared files');
    
    # Send the admin module over. Or could just do a checkout...
#    $self->system_call("rsync -Ca /home/tharris/projects/wormbase/website-admin/ $nfs_server:$nfs_root/admin",'rsyncing website admin module');

    $self->log->info("rsyncing other support files to nfs mount: $nfs_server: done");
}



# Keep the entire support databases directory in sync.
sub rsync_support_dbs_dir {
    my ($self,$node) = @_;
    my $root = $self->support_databases_dir;
    $self->log->info("rsyncing all (unpacked) support databases to $node");

    $self->system_call("rsync --rsh=ssh -Cav -z --exclude '*bak*' $root/ $node:$root/",
	'rsyncing support database directory');

    $self->log->info("rsyncing all (unpacked) support databases to $node");
}










sub update_dev_site_symlinks {    
    my $self = shift;
    $self->log->info("adjusting symlinks on development servers");

    my ($acedb_nodes)  = $self->development_acedb_nodes;

    my $acedb_root = $self->acedb_root;
    my $release    = $self->release;

    foreach my $node (@$acedb_nodes) {
	$self->log->debug("adjusting acedb symlink on $node");
	
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	$ssh->system("cd $acedb_root ; rm wormbase ; ln -s wormbase_$release wormbase") or
	    $self->log->logdie("remote command updating the acedb symlink failed " . $ssh->error);
	
    }

    $self->log->info("adjusting symlinks on mysql developmentservers");
    my ($nodes)  = $self->development_mysql_database_nodes;

    my $mysql_data_dir = $self->mysql_data_dir;
    my $manager        = $self->production_manager;
    foreach my $node (@$nodes) {
	$self->log->debug("adjusting mysql symlinks on $node");
	my ($species) = $self->wormbase_managed_species;  # Will be species updated this release.
	push @$species,'clustal';   # clustal database, too.
	foreach my $name (@$species) {
	    my $ssh = $self->ssh($node);
	    $ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);	
	    $ssh->system("cd $mysql_data_dir ; rm $name ; ln -s ${name}_$release $name") or
		$self->log->logdie("remote command updating the mysql symlink failed " . $ssh->error);
	}
    }  
}




1;
