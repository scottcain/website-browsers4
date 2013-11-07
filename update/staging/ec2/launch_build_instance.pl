#!/usr/bin/perl

use strict;
use VM::EC2;
use Getopt::Long;

my ($release,$help,$instance_count,$instance_type);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
	   'instances=i'   => \$instance_count,
	   'type=s'        => \$instance_type,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--instances --type] 

Start a new build instance and prepopulate it with data.

Options:
  --release     required. The WSXXX version of release to build.
  --instances   optional. Number of new prod instances to launch. Default: 1.
  --type        optional. Size of new instances to launch. Default: m1.xlarge

END

}

$instance_count ||= 1;
$instance_type  ||= 'm1.xlarge';

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);

#my $ftp_ip = get_internal_ip_of_ftp_instance();
my $ftp_ip = 'ftp.wormbase.org';

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
eval $(perl -Mlocal::lib=./)

# Update website-admin
cd /usr/local/wormbase/website-admin
git pull

# Unpack acedb
cd update/staging
./steps/unpack_acedb.pl --release $release
chown -R tharris:wormbase /usr/local/wormbase/acedb/wormbase_$RELEASE

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
./steps/dump_annotations.pl --release $RELEASE

# Xapian - widget ace dmp
./steps/create_widget_acedmp.pl --release $RELEASE

# Xapian - the actual data dump and indexing.
cd /usr/local/wormbase/website-admin/update/staging/xapian
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
g++ -o aceindex -L/usr/local/lib -l xapian -lconfig++ -I/usr/include/mysql -L/usr/lib/mysql -lmysqlclient_r aceindex.cc
./steps/build_xapian_db.pl --release $release

END
;

# Discover the build image. There should only be one.
my @i = $ec2->describe_images({'tag:Role' => 'build' });

if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple build AMIs. There can be only one. They are:

END
;
    
    foreach my $i (@i) {
	my $id          = $i->imageId; 
	my $location    = $i->imageLocation;
	my $architecture = $i->architecture;
	my $kernel_id   = $i->kernelId;
	my $name        = $i->name;
	my $description = $i->description;
	my @bdm         = $i->blockDeviceMapping;
	my $tags        = $i->tags;
	
	print "\t$i\t " . $tags->{Description} . "\n";
    }
    die;
}


my $build_image = $i[0];

print STDERR "Using AMI ID $build_image for building $release...\n";
print STDERR "\tlaunching $instance_count $instance_type instances of $build_image...\n";

my @instances = $build_image->run_instances(-min_count => $instance_count,
					    -max_count => $instance_count,
					    -key_name  => 'wormbase-development',
					    -security_group => 'wormbase-build',
					    -instance_type  => $instance_type,
					    -placement_zone => 'us-east-1d',
					    -shutdown_behavior => 'terminate',
					    -user_data         => $user_data,
#							    -block_devices => ['/dev/sdb=none',
#									       '/dev/sde=ephemeral0',
#									       '/dev/sdf=ephemeral1'],
    );

# Wait until the build instance is up and running.
$ec2->wait_for_instances(@instances);

my $instance = $instances[0];
tag_instance($instance);
tag_volume($instance);
display_instance_metadata($instance);

sub tag_instance {
    my $instance = shift;
    
    print STDERR "\ttagging instances with some metadata...\n";
    
    $instance->add_tags(
	Name        => "wb-build",
	Description => "build instance from AMI: $build_image",
	Status      => 'build',
	Role        => 'build',
	Release     => $release,				     
	Project     => 'WormBase',
	Client      => 'OICR',
	);
}


sub tag_volume {
    my $instance = shift;
    
    print STDERR "\ttagging volumes with some metadata...\n";

    # EBS volumes. There should only be one per instance.
    my @devices  = $instance->blockDeviceMapping; # a hashref
    
    foreach  my $d (@devices) {
#	    my $virtual_device = $d->deviceName;
#	    my $snapshot_id    = $d->snapshotId;
#	    my $volume_size    = $d->volumeSize;
#	    my $delete         = $d->deleteOnTermination;     
	
	# Need the actual volume; cannot add tags to block device mappings       
	my $volume = $d->volume;
	$ec2->add_tags(-resource_id => [ $volume ],
		       -tag         => { Name        => "build-root",
					 Description => "root volume for $instance $release",
					 Status      => 'build',
					 Role        => 'build',
					 Release     => $release,				     
					 Project     => 'WormBase',
					 Client      => 'OICR',
					 Attached    => $instance,
		       });
    }
}


sub display_instance_metadata {
    my $i = shift;

    print STDERR "A new build instance has been launched. It is:\n\n";
#    foreach my $i (@$i) {
	
	my $id         = $i->instanceId; 
	my $type       = $i->instanceType;
	my $state      = $i->instanceState;
	my $status     = $i->current_status;
	my $zone       = $i->availabilityZone;
	my $launched   = $i->launchTime;
	my @groups     = $i->groups;
	my $tags       = $i->tags;
	
	# Network information
	my $hostname   = $i->dnsName;
	my $private_ip = $i->privateIpAddress;
	my $public_ip  = $i->ipAddress;
	
	# EBS volumes
	# my $block_dev  = $meta->blockDeviceMapping; # a hashref
	
	print "  Instance: $id ($hostname)\n";
	print "\tprivate ip address: $private_ip\n";
	print "\t public ip address: $public_ip\n";
	print "\t    instance type : $type\n";
	print "\t             zone : $zone\n";
	print "\t            state : $state\n";
	print "\t           status : $status\n";
	print "\t              TAGS\n";
	foreach (sort keys %$tags) { 
	    print "\t                    $_ : $tags->{$_}\n";
	}
	print "\n\n";
	print "The build process may now commence on $public_ip\n\n";
#    }

}







# We want to use the INTERNAL IP of the FTP instance.
# Data transfer internally is free.
sub get_internal_ip_of_ftp_instance {
    my @i = $ec2->describe_instances({'tag:Status' => 'development' });
    
    if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple development instances running at the moment. 
	There should only be one. Please kill some of the extras and re-run.
	The running instances are:

END
print join("\t\n",@i);
    die;
}

    my $instance = $i[0];
    my $ip = $instance->privateIpAddress;
    return $ip;
}
