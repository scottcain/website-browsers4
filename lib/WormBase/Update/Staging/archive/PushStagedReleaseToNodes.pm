package WormBase::Update::Staging::PushStagedReleaseToNodes;

use Moose;
#use VM::EC2;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'push a staged release to specific nodes -- development OR production',
);

has 'ec2' => (
    is => 'ro',
    lazy_build => 1
    );

sub _build_ec2 {
    my $self = shift;
    my $access_key = $ENV{EC2_ACCESS_KEY};
    my $secret_key = $ENV{EC2_SECRET_KEY};
    
# get new EC2 object
    my $ec2 = VM::EC2->new(-access_key => $access_key,
			   -secret_key => $secret_key,
			   -endpoint   => 'http://ec2.amazonaws.com') or die "$!";
    return $ec2;
}

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
	    next if $node eq $self->staging_host;  # No need to push a staged release back to ourselves.
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
	    next if $node eq $self->staging_host;  # No need to push a staged release back to ourselves.
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
	    if ($target eq 'production') {
		next if $node eq $self->staging_host;  # No need to push a staged release back to ourselves.
		# $self->package_support_databases() if ($self->method eq 'by_package');	    
		$self->rsync_support_dbs_to_target_node($node);
		# Other approaches
		# $self->rsync_support_dbs_dir_to_nfs_mount($node);
		# $self->rsync_support_dbs_dir($node);
		# $self->rsync_support_dbs_package($node);
	    }
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
    
    $self->system_call("rsync --rsh=ssh -Cav --exclude serverlog.wrm --exclude log.wrm --exclude readlocks $database $node:$acedb_root/","rsyncing $database to $node");
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
    
    my $manager = $self->production_manager;
    my $ssh     = $self->ssh($node);
    $ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);	

    $ssh->system("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks") or
	$self->log->logdie("remote command fixing acedb permissions failed " . $ssh->error);
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
    
    my $manager        = $self->production_manager;

    my $ssh = $self->ssh($node);
    $ssh->error && $self->log->logdie("Can't ssh to $manager\@$node: " . $ssh->error);	
    $ssh->system("cd $root; pwd; chmod -R 2775 *$release",) or 
	$self->log->logdie("fixing mysql permissions failed " . $ssh->error);
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
#    $self->system_call("rsync -Cav $wormbase_root/website-shared-files $node:/usr/local/wormbase/",'rsyncing website shared files');
    
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
    $self->system_call("rsync -Cav $wormbase_root/website-shared-files $nfs_server:$nfs_root/",'rsyncing website shared files');
    
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




				       


=pod


Creating a new AMI for the newest release.
1. List all AMIs, and discover which is the newest Core
2. Launch a new instance of the core AMI
3. Provision a new EBS volume of 300 GB.
4. Attach EBS volume to /dev/sdg 
5. Attach the Core volume which has relatively static content (website, mysql, etc) to /dev/sdf (vol-53ae003d)
--
6. SSH to the new instance and execute the following commands
    > sudo mkfs /dev/xdg             # format the volume
    > sudo mount /dev/xdg /mnt/ebs   # Mount the volume

    > sudo mount /dev/xdf            /mnt/temp   # Mount our core volume with all of our files.
    > sudo mkdir /mnt/ebs/wormbase
    > sudo chown tharris:wormbase /mnt/ebs/wormbase
    > sudo chmod 2775 /mnt/ebs/wormbase
        
    > sudo mkdir /mnt/ebs/mysql    
    > sudo chown tharris:wormbase /mnt/ebs/wormbase
    > sudo chmod 2775 /mnt/ebs/wormbase

    # Set up some symbolic mounts.
    > sudo mount /usr/local/wormbase /mnt/ebs/wormbase   # symbolic volumes
    > sudo mount /var/lib/mysql      /mnt/ebs/mysql

7. Copy core information from /mnt/temp
    > sudo cp -rp /mnt/temp/mysql/* /mnt/ebs/mysql/*
    > sudo chown -R mysql:mysql /mnt/ebs/mysql
    > cp -pr /mnt/temp/wormbase/* /mnt/ebs/wormbase/*
8. Push data onto the instance as before
9. Unmount all volumes
   # The symbolic mounts
   > sudo umount /usr/local/wormbase
   > sudo umount /var/lib/mysql
   # The actual EBS mounts
   > sudo umount /mnt/ebs
   > sudo umount /mnt/temp
10. Detach volumes via the API
11. Add tags to the new volume: date created, release, etc.
12. From the instance, create a new core AMI
13. Delete the old Core AMI; retain the volume
14. Shut down the core AMI

# Going live.
1. Launch instances of the AMI.
2. Attach the new EBS volume via the API.
3. Mount the new EBS volume attached at /dev/sdg
    > sudo mount /dev/xvdg /mnt/ebs

4. Create symbolic mounts
    > sudo mkdir /mnt/ephemeral0/wormbase
    > sudo chown tharris:wormbase /mnt/ephemeral0/wormbase
    > sudo chmod 2775 /mnt/ephemeral0/wormbase
        
    > sudo mkdir /mnt/ephemeral1/mysql    
    > sudo chown mysql:mysql /mnt/ephemeral1/mysql
    > sudo chmod 2775 /mnt/ephemeral1/mysql

    > sudo mount /usr/local/wormbase /mnt/ephemeral0/wormbase   # symbolic volumes
    > sudo mount /var/lib/mysql      /mnt/ephemeral1/mysql 

5. Copy EBS contents to ephemeral storage
    > sudo cp -rp /mnt/ebs/wormbase /mnt/ephemeral0/wormbase/. 
    > sudo cp -rp /mnt/ebs/mysql    /mnt/ephemeral1/mysql/. 

6. Update software
    > cd /usr/local/wormbase/website/production ; git pull
7. Unmount the EBS reference volume
    > sudo umount /mnt/ebs
8. Detach the volume via the API
   -- repeat for all new instances --
9. When finished, update the IPs to our static addresses.
10. Kill instances running the old versions.
11. Retain core AMIs and single EBS for each version.

#!/usr/bin/perl

use strict;
use VM::EC2;

my $access_key = $ENV{EC2_ACCESS_KEY};
my $secret_key = $ENV{EC2_SECRET_KEY};

# get new EC2 object
my $ec2 = VM::EC2->new(-access_key => $access_key,
		       -secret_key => $secret_key,
		       -endpoint   => 'http://ec2.amazonaws.com') or die "$!";

# find existing volumes that are available
#my @volumes = $ec2->describe_volumes({status=>'available'});
#print @volumes;

# fetch the Core WormBase AMI.
my $image = $ec2->describe_images('ami-e8bf1e81');
my $name  = $image->name;
my $state   = $image->imageState;
my $owner   = $image->imageOwnerId;
my $rootdev = $image->rootDeviceName;
my @devices = $image->blockDeviceMapping;
my $tags    = $image->tags;

print "name\t$name\n";
print "state\t$state\n";
print "owner\t$owner\n";
print "rootdev\t$rootdev\n";



sub build_new_core_ami {
    my $self = shift;

    # Create a new EBS volume for this release.
    my $volume   = $self->provision_new_volume;

    # Launch a new instance of the core AMI
    my $instance = $self->launch_new_core_instance;

    # Attach my new EBS volume so I can dump data onto it.
    $self->attach_new_ebs_volume($volume,$instance);

    # Attach the core MySQL volume ( vol-53ae003d)
    $self->attach_core_mysql_volume('vol-53ae003d',$instance);
    
    # Connect and format, then mount volume.

}

sub provision_new_ebs_volume {
    my $self = shift;
    my $ec2  = $self->ec2;
    
    my $vol = $ec2->create_volume(-availability_zone => 'us-east-1d',
                                   -size             =>  300);
    $ec2->wait_for_volumes($vol);
    $self->log->info("volume $vol is ready!\n" if $vol->current_status eq 'available');
    return $vol;
}


sub launch_new_core_instance {
    my $self = shift;
    my $ec2   = $self->ec2;

    # The core image ID is hard-coded here. But it will change from release to release.
    # Need to discover what it is.
    my $image = $ec2->describe_images('ami-e8bf1e81');
    my $instance = $ec2->run_instance({-instance_type => 'm1.large'});
    return $instance;  # Should check to make sure the instance has launched.
}


sub attach_new_ebs_volume {
    my ($self,$volume,$instance) = @_;    
    $instance->attach_volume($vol=>'/dev/sdg');    
}

=cut
    



1;
