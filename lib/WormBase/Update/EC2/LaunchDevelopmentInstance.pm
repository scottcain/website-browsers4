package WormBase::Update::EC2::LaunchDevelopmentInstance;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'launch a new instance of the core WormBase AMI; this will become the devleopment env',
);

# Number of instances to launch; optionally supplied to constructor.
has 'instance_count' => (
    is => 'rw',
    required => 1,
    );

# Size of instances to launch; optionally supplied by contructor.
has 'instance_type' => (
    is => 'rw',
    required => 1,
    );


has 'user_data' => (
    is => 'ro',
    lazy_build => 1
    );


sub _build_user_data {
    my $self   = shift;
    
    my $ftp_ip = $self->get_internal_ip_of_ftp_instance();
#    my $ftp_ip = 'ftp.wormbase.org';
    my $release = $self->release;
    
my $user_data = <<END;
#!/bin/bash

# Stop services
/etc/init.d/mysql stop
killall -9 sgifaceserver

# Remove old mounts
umount /var/lib/mysql
umount /var/log/mysql
umount /etc/mysql
umount /usr/local/wormbase/

# Ensure that any future AMIs created from this instance 
# can also use user_data
insserv -d ec2-run-user-data

################################################
# Set up directories on ephemeral storage
################################################
mkdir -p /mnt/ephemeral0/usr/local/wormbase/databases
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/databases
mount --bind /mnt/ephemeral0/usr/local/wormbase/databases /usr/local/wormbase/databases

# acedb
mkdir -p /mnt/ephemeral0/usr/local/wormbase/acedb
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/acedb
# Need to move binaries over first
cp -rp /usr/local/wormbase/acedb/. /mnt/ephemeral0/usr/local/wormbase/acedb/.
mount --bind /mnt/ephemeral0/usr/local/wormbase/acedb /usr/local/wormbase/acedb

# tmp directory
mkdir /usr/local/wormbase/tmp
mkdir -p /mnt/ephemeral0/usr/local/wormbase/tmp
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/tmp
mount --bind /mnt/ephemeral0/usr/local/wormbase/tmp /usr/local/wormbase/tmp

# The FTP dirs, where we will copy files from the primary FTP site.
mkdir -p /mnt/ephemeral1/usr/local/ftp/pub/wormbase
mkdir -p /usr/local/ftp/pub/wormbase
chown -R tharris:wormbase /usr/local/ftp/
chmod -R 2775 /usr/local/ftp
mount --bind /mnt/ephemeral1/usr/local/ftp/pub/wormbase /usr/local/ftp/pub/wormbase
cd /usr/local/ftp/pub/wormbase
mkdir releases
mkdir species
chown -R tharris:wormbase /usr/local/ftp/pub/wormbase
chmod -R 2775 /usr/local/ftp/pub/wormbase
# Do I need to create other directories?

# MySql databases/libs
mkdir -p /mnt/ephemeral1/var/lib/mysql
mkdir -p /mnt/ephemeral1/var/log/mysql
mkdir -p /mnt/ephemeral1/etc/mysql
cp -rp /var/lib/mysql/* /mnt/ephemeral1/var/lib/mysql/.
cp -rp /var/log/mysql/* /mnt/ephemeral1/var/log/mysql/.
cp -rp /etc/mysql/* /mnt/ephemeral1/etc/mysql/.
mount --bind /mnt/ephemeral1/var/lib/mysql /var/lib/mysql
mount --bind /mnt/ephemeral1/var/log/mysql /var/log/mysql
mount --bind /mnt/ephemeral1/etc/mysql     /etc/mysql
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/log/mysql
chown -R mysql:mysql /etc/mysql
/etc/init.d/mysql restart

# Mirror files from dev.wormbase.org to ephemeral storage using it's private ip address
cd /usr/local/ftp/pub/wormbase/releases
wget --mirror -nH --cut-dirs=3 ftp://$ftp_ip/pub/wormbase/releases/$release 
chown -R tharris:wormbase $release/

# perllib - add to my .profile. Not very portable...
cd /usr/local/wormbase/extlib
perl -Mlocal::lib=./ >> /home/tharris/.bash_profile
eval \$\(perl -Mlocal::lib=./\)

# Update website-admin
cd /usr/local/wormbase/website-admin
git pull

# Unpack acedb
cd update/staging
./steps/unpack_acedb.pl --release $release
chown -R tharris:wormbase /usr/local/wormbase/acedb/wormbase_$release

# Create blast databases
./steps/create_blast_databases.pl --release $release
chown -R tharris:wormbase /usr/local/wormbase/databases

# Load up the clustal database
./steps/unpack_clustal_database.pl --release $release

# Mirror ontology files
./steps/compile_ontology_resources.pl --release $release

# Mirror wikipathways images
./steps/mirror_wikipathways_images.pl --release $release

# Create commonly requested files
./steps/dump_annotations.pl --release $release

# Xapian - widget ace dmp
./steps/create_widget_acedmp.pl --release $release

# Xapian - the actual data dump and indexing.
cd /usr/local/wormbase/website-admin/update/staging/xapian
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/lib
g++ -o aceindex -L/usr/local/lib -l xapian -lconfig++ -I/usr/include/mysql -L/usr/lib/mysql -lmysqlclient_r aceindex.cc
./steps/build_xapian_db.pl --release $release

# Build new GBrowse configuration files
# These will end up in website/tharris
./steps/create_gbrowse_configuration.pl --release $release

END
;

}

sub run {
    my $self = shift;           

    # Get the CURRENT dvelopment instance.
    my $old_instance = $self->get_current_development_instance();

    my $instances = $self->_launch_instance();

    $self->tag_instances({ instances   => $instances,
			   description => 'development instance from AMI: ' . $self->image,
			   name        => 'wb-development',
			   status      => 'development',
			   role        => 'appserver',
			   source_ami  => $self->image,
			 });

    $self->tag_volumes({ instances   => $instances,
			 description => 'development instance from AMI: ' . $self->image,
			 name        => 'wb-development',  # this is the name root
			 status      => 'development',
			 role        => 'appserver',
		       });

    $self->log->info("A new development instance has been launched");
    $self->display_instance_metadata($instances);
}	    



sub _launch_instance  {
    my $self = shift;

    # Get the core image.
    my $image = $self->core_image();
    
    my $instance_count = $self->instance_count;
    my $instance_type  = $self->instance_type;

    my $release = $self->release;
    
    $self->log->info("Using AMI ID $image for launching a new development instance");
    $self->log->info("launching $instance_count $instance_type instances of $image");
    
    my @instances = $image->run_instances(-min_count => $instance_count,
						-max_count => $instance_count,
						-key_name  => 'wormbase-development',
						-security_group => 'wormbase-development',
						-instance_type  => $instance_type,
						-placement_zone => 'us-east-1d',
						-shutdown_behavior => 'terminate',
						-user_data         => $self->user_data,
#							    -block_devices => ['/dev/sdb=none',
#									       '/dev/sde=ephemeral0',
#									       '/dev/sdf=ephemeral1'],
	);

    # Wait until the instances are up and running.
    $self->log->info("Waiting for instances to launch...");
    my $ec2 = $self->ec2;
    $ec2->wait_for_instances(@instances);
    return \@instances;   
}




sub get_current_development_instance {
    my $self = shift;
    my $ec2 = $self->ec2;
    
    $self->log->info("Fetching current development instance.");
    
    # Discover the current development instance.
    # Hopefully it exists. We assume there is only one.
    my @i = $self->get_instances({'tag:Status'     => 'development',
				  'instance-state-name' => 'running',
				 });
    
    if (@i > 1) { 
	print STDERR <<END;
	
        Um. 
	    There seem to be multiple development instances running at the moment. 
	    There should only be one. Please kill some of the extras and re-run.
	    The running instances are:

END
;
	
	$self->display_instance_metadata(\@i);
	die;
    }

    my $instance = $i[0];
    $self->display_instance_metadata([$instance]);    
    
    $self->log->info("Found the development image for $release: $image");
    return $instance;
}
    

1;
