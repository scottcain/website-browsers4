package WormBase::Update::EC2::LaunchBuildInstance;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'launch a new instance of the build AMI; begin the build via user data',
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
# Formerly, these were mounts in fstab in the build AMI
#umount /var/lib/mysql
#umount /var/log/mysql
#umount /etc/mysql
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
# Relocating acedb to ephemeral storage
#mkdir -p /mnt/ephemeral0/usr/local/wormbase/acedb
#chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
#chmod 2775 /mnt/ephemeral0/usr/local/wormbase/acedb
# Need to move binaries over first
#cp -rp /usr/local/wormbase/acedb/. /mnt/ephemeral0/usr/local/wormbase/acedb/.
#mount --bind /mnt/ephemeral0/usr/local/wormbase/acedb /usr/local/wormbase/acedb

# Relocate acedb to ebs. Already configured by system.
#mkdir -p /mnt/ebs1/usr/local/wormbase/acedb
#chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
#chmod 2775 /mnt/ebs1/usr/local/wormbase/acedb
## Need to move binaries over first
#cp -rp /usr/local/wormbase/acedb/. /mnt/ebs1/usr/local/wormbase/acedb/.
#mount --bind /mnt/ephemeral0/usr/local/wormbase/acedb /usr/local/wormbase/acedb

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
# Relocating mysql to ephemeral storage (or any other mount point)
# Duplicate and update paths to relocate mysql to an EBS mount
#mkdir -p /mnt/ephemeral1/var/lib/mysql
#mkdir -p /mnt/ephemeral1/var/log/mysql
#mkdir -p /mnt/ephemeral1/etc/mysql
#cp -rp /var/lib/mysql/* /mnt/ephemeral1/var/lib/mysql/.
#cp -rp /var/log/mysql/* /mnt/ephemeral1/var/log/mysql/.
#cp -rp /etc/mysql/* /mnt/ephemeral1/etc/mysql/.
#mount --bind /mnt/ephemeral1/var/lib/mysql /var/lib/mysql
#mount --bind /mnt/ephemeral1/var/log/mysql /var/log/mysql
#mount --bind /mnt/ephemeral1/etc/mysql     /etc/mysql
#chown -R mysql:mysql /var/lib/mysql
#chown -R mysql:mysql /var/log/mysql
#chown -R mysql:mysql /etc/mysql
#/etc/init.d/mysql restart

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

# Load genomic GFF databases
./steps/load_genomic_gff_databases.pl --release $release

# Update Symlinks on the FTP site
./steps/update_ftp_site_symlinks.pl --release $release --status development

# Rsync back to the development server:
./steps/rsync_ephemeral_build_to_stable_host.pl --release $release


END
;

}

sub run {
    my $self = shift;           
    my $instances = $self->_launch_instance();

    $self->tag_instances({ instances   => $instances,
			   description => 'build instance from AMI: ' . $self->build_image,
			   name        => 'wb-build',
			   status      => 'build',
			   role        => 'appserver',
			   source_ami  => $self->build_image,
			 });

    $self->tag_volumes({ instances   => $instances,
			 description => 'build instance from AMI: ' . $self->build_image,
			 name        => 'wb-build',  # this is the name root
			 status      => 'build',
			 role        => 'appserver',
		       });

    $self->log->info("The build instance has been launched and the build process launched on:");
    $self->display_instance_metadata($instances);
}	    



sub _launch_instance  {
    my $self = shift;

    # Discover the build image. There should only be one.
    my $build_image = $self->build_image();
    
    my $instance_count = $self->instance_count;
    my $instance_type  = $self->instance_type;

    my $release = $self->release;
    
    $self->log->info("Using AMI ID $build_image for building $release");
    $self->log->info("launching $instance_count $instance_type instances of $build_image");
    
    my @instances = $build_image->run_instances(-min_count => $instance_count,
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




1;
