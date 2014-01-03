package WormBase::Update::EC2::LaunchBuildInstance;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'launch a new instance of the build AMI; begin the build via user data',
);

# The elastic IP address used for the build instance.
has 'ip_address' => (
    is => 'ro',
    default => '50.19.229.229',
);


# Size of the required data mount, in GB
has 'data_volume_size' => (
    is => 'ro',
    default => 300
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
    my $release = $self->release;
    
my $user_data = <<END;
#!/bin/bash

# Stop services
/etc/init.d/mysql stop
killall -9 sgifaceserver

# Ensure that any future AMIs created from this instance 
# can also use user_data
insserv -d ec2-run-user-data

# Format our new disk
echo "configuring new volume..."
mkfs.ext3 /dev/xvdg
mount /dev/xvdg /mnt/ebs1

################################################
# Set up directories on ebs (or ephemeral) storage.
# Since the build process is temporary, let's
# just do everything on EBS for performance reasons.
#
# Note that /usr/local/wormbase is a path on the root
# EBS mount.
################################################
# /usr/local/wormbase/databases
echo "Relocating the databases/ to ebs"
mkdir -p /mnt/ebs1/usr/local/wormbase/databases
chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
chmod 2775 /mnt/ebs1/usr/local/wormbase/databases
mount --bind /mnt/ebs1/usr/local/wormbase/databases /usr/local/wormbase/databases

#echo "Relocating the databases/ to ephemeral"
#mkdir -p /mnt/ephemeral0/usr/local/wormbase/databases
#chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
#chmod 2775 /mnt/ephemeral0/usr/local/wormbase/databases
#mount --bind /mnt/ephemeral0/usr/local/wormbase/databases /usr/local/wormbase/databases

# /usr/local/wormbase/acedb
echo "Relocating acedb to ebs..."
mkdir -p /mnt/ebs1/usr/local/wormbase/acedb
chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
chmod 2775 /mnt/ebs1/usr/local/wormbase/acedb
cp -rp /usr/local/wormbase/acedb/. /mnt/ebs1/usr/local/wormbase/acedb/.
mount --bind /mnt/ebs1/usr/local/wormbase/acedb /usr/local/wormbase/acedb

# Alternative: relocate acedb to ephemeral storage - BAD PERFORMANCE!
# echo "Relocating acedb to ephemeral storage..."
#mkdir -p /mnt/ephemeral0/usr/local/wormbase/acedb
#chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
#chmod 2775 /mnt/ephemeral0/usr/local/wormbase/acedb
# Need to move binaries over first
#cp -rp /usr/local/wormbase/acedb/. /mnt/ephemeral0/usr/local/wormbase/acedb/.
#mount --bind /mnt/ephemeral0/usr/local/wormbase/acedb /usr/local/wormbase/acedb

# /usr/local/wormbase/tmp
echo "Relocating tmp/ to ebs..."
mkdir /usr/local/wormbase/tmp
mkdir -p /mnt/ebs1/usr/local/wormbase/tmp
chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
chmod 2775 /mnt/ebs1/usr/local/wormbase/tmp
mount --bind /mnt/ebs1/usr/local/wormbase/tmp /usr/local/wormbase/tmp

# Alternative: relocate /tmp to ephemeral storage (bad performance on SeqFeature loads...)
#echo "Relocating tmp/ to ephemeral storage..."
#mkdir /usr/local/wormbase/tmp
#mkdir -p /mnt/ephemeral0/usr/local/wormbase/tmp
#chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
#chmod 2775 /mnt/ephemeral0/usr/local/wormbase/tmp
#mount --bind /mnt/ephemeral0/usr/local/wormbase/tmp /usr/local/wormbase/tmp

# /usr/local/ftp
echo "Creating a temporary FTP directory on ebs ..."
mkdir -p /mnt/ebs1/usr/local/ftp/pub/wormbase
mkdir -p /usr/local/ftp/pub/wormbase
chown -R tharris:wormbase /usr/local/ftp/
chmod -R 2775 /usr/local/ftp
mount --bind /mnt/ebs1/usr/local/ftp/pub/wormbase /usr/local/ftp/pub/wormbase
cd /usr/local/ftp/pub/wormbase
mkdir releases
mkdir species
chown -R tharris:wormbase /usr/local/ftp/pub/wormbase
chmod -R 2775 /usr/local/ftp/pub/wormbase

#echo "Creating a temporary FTP directory on ephemeral storage..."
#mkdir -p /mnt/ephemeral1/usr/local/ftp/pub/wormbase
#mkdir -p /usr/local/ftp/pub/wormbase
#chown -R tharris:wormbase /usr/local/ftp/
#chmod -R 2775 /usr/local/ftp
#mount --bind /mnt/ephemeral1/usr/local/ftp/pub/wormbase /usr/local/ftp/pub/wormbase
#cd /usr/local/ftp/pub/wormbase
#mkdir releases
#mkdir species
#chown -R tharris:wormbase /usr/local/ftp/pub/wormbase
#chmod -R 2775 /usr/local/ftp/pub/wormbase


# MySQL directories
echo "Relocating mysql to ebs..."
/etc/init.d/mysql stop
rm -rf /mnt/ebs1/var/lib/mysql
rm -rf /mnt/ebs1/var/log/mysql
rm -rf /mnt/ebs1/etc/mysql
mkdir -p /mnt/ebs1/var/lib/mysql
mkdir -p /mnt/ebs1/var/log/mysql
mkdir -p /mnt/ebs1/etc/mysql
mount --bind /mnt/ebs1/var/lib/mysql /var/lib/mysql
mount --bind /mnt/ebs1/var/log/mysql /var/log/mysql
mount --bind /mnt/ebs1/etc/mysql     /etc/mysql
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/log/mysql
chown -R mysql:mysql /etc/mysql
# reinitialize mysql and set my root password.
cd /usr/local/mysql
./scripts/mysql_install_db  --user=mysql --datadir=/var/lib/mysql
/etc/init.d/mysql restart

# echo "Relocating mysql to ephemeral storage..."
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
echo "Mirroring files from ftp.wormbase.org..."
cd /usr/local/ftp/pub/wormbase/releases
wget --mirror -nH --cut-dirs=3 ftp://$ftp_ip/pub/wormbase/releases/$release 
chown -R tharris:wormbase $release/

# perllib - add to my .profile. Not very portable...
echo "Setting up perllib environment..."
cd /usr/local/wormbase/extlib
perl -Mlocal::lib=./ >> /home/tharris/.bash_profile
eval \$\(perl -Mlocal::lib=./\)

# Update website-admin
echo "Updating the website-admin repo..."
cd /usr/local/wormbase/website-admin
git pull

# checkout source for gbrowse built files
echo "Checking out website source for building gbrowse config..."
cd /usr/local/wormbase
git clone git@github.com:WormBase/website.git
mv website tharris
cd tharris
git checkout staging

# Unpack acedb
echo "Unpacking acedb..."
cd update/staging
./steps/unpack_acedb.pl --release $release
chown -R tharris:wormbase /usr/local/wormbase/acedb/wormbase_$release

# Create blast databases
echo "Creating blast databases..."
./steps/create_blast_databases.pl --release $release
chown -R tharris:wormbase /usr/local/wormbase/databases

# Load up the clustal database
echo "Loading clustal database..."
./steps/unpack_clustal_database.pl --release $release

# Mirror ontology files
echo "Mirroring ontology files..."
./steps/compile_ontology_resources.pl --release $release

# Mirror wikipathways images
echo "Mirroring wikipathways images..."
./steps/mirror_wikipathways_images.pl --release $release

# Create commonly requested files
echo "Dumping common annotations..."
./steps/dump_annotations.pl --release $release

# Xapian - widget ace dmp
echo "Creating mysql dump for xapian..."
./steps/create_widget_acedmp.pl --release $release

# Xapian - the actual data dump and indexing.
echo "Creating xapian search database..."
cd /usr/local/wormbase/website-admin/update/staging/xapian
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/lib
g++ -o aceindex -L/usr/local/lib -l xapian -lconfig++ -I/usr/include/mysql -L/usr/lib/mysql -lmysqlclient_r aceindex.cc
cd /usr/local/wormbase/website-admin/update/staging
./steps/build_xapian_db.pl --release $release

# Build new GBrowse configuration files
# These will end up in website/tharris
echo "Creating GBrowse configuration files..."
cd /usr/local/wormbase/website-admin/update/staging
./steps/create_gbrowse_configuration.pl --release $release

# Load genomic GFF databases
echo "Loading genomic GFF databases..."
cd /usr/local/wormbase/website-admin/update/staging
./steps/load_genomic_gff_databases.pl --release $release

# Update Symlinks on the FTP site
echo "Updating symlinks on the FTP site..."
cd /usr/local/wormbase/website-admin/update/staging
./steps/update_ftp_site_symlinks.pl --release $release --status development

# Rsync back to the development server:
echo "Rsyncing build back to the development server..."
cd /usr/local/wormbase/website-admin/update/staging
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
			   role        => 'webapp',
			   source_ami  => $self->build_image,
			 });

    $self->tag_volumes({ instances   => $instances,
			 description => 'build instance from AMI: ' . $self->build_image,
			 name        => 'wb-build',  # this is the name root
			 status      => 'build',
			 role        => 'webapp',
		       });

    # Assuming here that the IP address is already disocciated.
    $self->associate_ip_address($instances->[0],$self->ip_address);

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

    my $size = $self->data_volume_size;

    my @instances = $build_image->run_instances(-min_count => $instance_count,
						-max_count => $instance_count,
						-key_name  => 'wormbase-development',
						-security_group => 'wormbase-development',
						-instance_type  => $instance_type,
						-placement_zone => 'us-east-1d',
						-shutdown_behavior => 'terminate',
						-user_data         => $self->user_data,
						-block_devices => [ '/dev/sde=ephemeral0',
								    '/dev/sdf=ephemeral1',
								    "/dev/sdg=:$size:true"],
	);

    # Wait until the instances are up and running.
    $self->log->info('Waiting for instances to launch...');
    my $ec2 = $self->ec2;
    $ec2->wait_for_instances(@instances);
    return \@instances;   
}




1;
