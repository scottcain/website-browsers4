#!/usr/bin/perl

# Launch new production instances from the core webapp AMI.

use strict;
use VM::EC2;
use VM::EC2::Staging::Manager;
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

Launch new instances of the core webapp AMI.

Options:
  --release     required. The WSXXX version of release to build.
  --instances   optional. Number of new prod instances to launch. Default: 1.
  --type        optional. Size of new instances to launch. Default: m1.large

END

}

$instance_count ||= 1;
$instance_type  ||= 'm1.large';

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint   => 'http://ec2.amazonaws.com',
		       -print_error => 1);

# Find the correct image.
my @i = $ec2->describe_images({'tag:Status'  => 'production',
			       'tag:Role'    => 'webapp',
			       'tag:Release' => $release
			      });

if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple webapp production images.
	There should only be one. Please figure out what is
	going on before proceeding.

END
print join("\t\n",@i);
    die;
}


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

# Format our new disk
echo "configuring new volume..."
mkfs.ext3 /dev/xvdg
mount /dev/xvdg /mnt/ebs1

################################################
# Move acedb and the tmp dir to our new disk.
################################################
echo "setting up acedb/ ..."
mkdir /usr/local/wormbase/acedb
mkdir -p /mnt/ebs1/usr/local/wormbase/acedb
chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
chmod 2775 /mnt/ebs1/usr/local/wormbase/acedb
cp -rp /mnt/ebs0/usr/local/wormbase/acedb/. /mnt/ebs1/usr/local/wormbase/acedb/.
mount --bind /mnt/ebs1/usr/local/wormbase/acedb /usr/local/wormbase/acedb

# tmp directory
echo "setting up temporary/ ..."
mkdir /usr/local/wormbase/tmp
mkdir -p /mnt/ephemeral0/usr/local/wormbase/tmp
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/tmp
mount --bind /mnt/ephemeral0/usr/local/wormbase/tmp /usr/local/wormbase/tmp

################################################
# Set up directories on ephemeral storage
################################################
# /usr/local/wormbase/databases
echo "setting up databases/ ..."
mkdir /usr/local/wormbase/databases
chown -R tharris:wormbase /usr/local/wormbase/databases
mkdir -p /mnt/ephemeral0/usr/local/wormbase/databases
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/databases
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/databases
mount --bind /mnt/ephemeral0/usr/local/wormbase/databases /usr/local/wormbase/databases
cp -rp /mnt/ebs0/usr/local/wormbase/databases/$release /mnt/ephemeral0/usr/local/wormbase/databases/.

# /usr/local/wormbase/website
echo "setting up website/ ..."
mkdir /usr/local/wormbase/website
mkdir -p /mnt/ephemeral0/usr/local/wormbase/website
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/website
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/website
mount --bind /mnt/ephemeral0/usr/local/wormbase/website /usr/local/wormbase/website
cp -rp /mnt/ebs0/usr/local/wormbase/website/* /mnt/ephemeral0/usr/local/wormbase/website/.

# /usr/local/wormbase/website-shared-files
echo "setting up website-shared-files/ ..."
mkdir /usr/local/wormbase/website-shared-files
mkdir -p /mnt/ephemeral0/usr/local/wormbase/website-shared-files
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/website-shared-files
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/website-shared-files
mount --bind /mnt/ephemeral0/usr/local/wormbase/website-shared-files /usr/local/wormbase/website-shared-files
cp -rp /mnt/ebs0/usr/local/wormbase/website-shared-files/* /mnt/ephemeral0/usr/local/wormbase/website-shared-files/.

# /usr/local/wormbase/website-admin
echo "setting up website-admin/ ..."
mkdir /usr/local/wormbase/website-admin
mkdir -p /mnt/ephemeral0/usr/local/wormbase/website-admin
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/website-admin
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/website-admin
mount --bind /mnt/ephemeral0/usr/local/wormbase/website-admin /usr/local/wormbase/website-admin
cp -rp /mnt/ebs0/usr/local/wormbase/website-admin/* /mnt/ephemeral0/usr/local/wormbase/website-admin/.

# /usr/local/wormbase/extlib
echo "setting up extlib/ ..."
mkdir /usr/local/wormbase/extlib
mkdir -p /mnt/ephemeral0/usr/local/wormbase/extlib
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/extlib
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/extlib
mount --bind /mnt/ephemeral0/usr/local/wormbase/extlib /usr/local/wormbase/extlib
cp -rp /mnt/ebs0/usr/local/wormbase/extlib/* /mnt/ephemeral0/usr/local/wormbase/extlib/.

# MySql databases. These will eventually be on RDS
echo "setting up mysql/ ..."
mkdir -p /mnt/ephemeral1/var/lib/mysql
mkdir -p /mnt/ephemeral1/var/log/mysql
mkdir -p /mnt/ephemeral1/etc/mysql
cp -rp /mnt/ebs0/lib/mysql/* /mnt/ephemeral1/var/lib/mysql/.
cp -rp /mnt/ebs0/log/mysql/* /mnt/ephemeral1/var/log/mysql/.
cp -rp /mnt/ebs0/etc/mysql/* /mnt/ephemeral1/etc/mysql/.
mount --bind /mnt/ephemeral1/var/lib/mysql /var/lib/mysql
mount --bind /mnt/ephemeral1/var/log/mysql /var/log/mysql
mount --bind /mnt/ephemeral1/etc/mysql     /etc/mysql
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/log/mysql
chown -R mysql:mysql /etc/mysql
/etc/init.d/mysql restart

# Unmount /dev/sdb
echo "unmounting the reference volume ..."
umount /mnt/ebs0

# perllib - add to my .profile. Not very portable...
cd /usr/local/wormbase/extlib
perl -Mlocal::lib=.\/ >> /home/tharris/.bash_profile
eval $(perl -Mlocal::lib=.\/)

echo "Preconfiguration is complete!"
echo "You should now :"
echo "    > saceclient localhost -port 2005  -- to start sgifaceserver"
echo "    > cd /usr/local/wormbase/website/production ; ./script/wormbase-daemons.sh -- to start webapp"

echo "Be sure to update the reverse proxy config with new *internal* IP address of this host! It is:"

IP=`GET http://169.254.169.254/latest/meta-data/local-ipv4`
echo "local private IP: \$IP"

# TO DO: should send an email
# with hostname, etc.


END
;

my $production_image = $i[0];

# Now, launch [number] [type] instances.
# Need to pass in user data, too.
print STDERR "launching $instance_count $instance_type instances of $production_image for $release...\n";
my @production_instances = $production_image->run_instances(-min_count => $instance_count,
							    -max_count => $instance_count,
							    -key_name  => 'wormbase-webapp',
							    -security_group => 'wormbase-production-webapp',
							    -instance_type  => $instance_type,
							    -placement_zone => 'us-east-1d',
							    -shutdown_behavior => 'terminate',
							    -user_data         => $user_data,
							    -block_devices => [
									       '/dev/sde=ephemeral0',
									       '/dev/sdf=ephemeral1',
                                                                               '/dev/sdg=:50:true'],
    );

# Wait until the production instances have launched.
$ec2->wait_for_instances(@production_instances);

# Tag 'em
tag_instances(\@production_instances);
#delete_data_volume(\@production_instances);
tag_volumes(\@production_instances);
display_instance_metadata(\@production_instances);


sub tag_instances {
    my $instances = shift;

    print STDERR "Tagging instances with some metadata...\n";
    foreach my $instance (@$instances) {
	$ec2->add_tags(-resource_id => [ $instance ],
		       -tag         => { Name         => "wb-webapp-$release-$instance",
					 Description  => "webapp instance from AMI: $production_image",
					 Status       => 'production',
					 Role         => 'webapp',
					 Release      => $release,				     
					 Project      => 'WormBase',
					 Source_AMI   => $production_image, 
					 Client       => 'OICR',
		       });	
    }
}


sub tag_volumes {
    my $instances = shift;
    
    print STDERR "Tagging volumes with metadata...\n";
    foreach my $instance (@$instances) {
	# EBS volumes. There should only be one per instance.
	my @devices  = $instance->blockDeviceMapping; # a hashref

	foreach  my $d (@devices) {
	    my $virtual_device = $d->deviceName;
#	    my $snapshot_id    = $d->snapshotId;
#	    my $delete         = $d->deleteOnTermination;     
	    
	    # Need the actual volume; cannot add tags to block device mappings
	    my $volume = $d->volume;
	    my $volume_size = $volume->size;

	    my $type = ($volume_size < 20) ? 'root' : 'data';
	    my $name = "wb-webapp-$type-$instance";

	    # This is the reference data volume
	    if ($volume_size > 250) {
		$name .= '-reference-SAFE-TO-DETACH-AND-DELETE';
	    }

	    $ec2->add_tags(-resource_id => [ $volume ],
			   -tag         => { Name        => $name,
					     Description => "$type volume for $instance $release",
					     Status      => 'production',
					     Role        => "webapp-$type",
					     Release     => $release,				     
					     Project     => 'WormBase',
					     Client      => 'OICR',
					     Attachment  => "$instance:$virtual_device",
			 });
	}
	
    }
}



sub display_instance_metadata {
    my $i = shift;

    print STDERR "$instance_count new production instances have been launched. They are:\n\n";
    foreach my $i (@$i) {
	
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
	print "\n";
    }
}




# Detach then delete the data volume.
# It should *already* have been unmounted by the configuration script.
sub delete_data_volume {
    my $instances = shift;

    foreach my $i (@$instances) {
	print "Detaching and deleting reference data volume from $i...\n";
	my @devices = $i->blockDeviceMapping;
	foreach my $d (@devices) {
	    my $virtual_device = $d->deviceName;
	    if ($virtual_device =~ /sdb/) {

		my $volume = $d->volume;
		my $a = $ec2->detach_volume($volume);
		$ec2->wait_for_attachments($a);
		if ($a->current_status eq 'detached') {
		    print "\t ... volume $d detached.\n";
		    my $status = $ec2->delete_volume($volume);
		    print "\t ... volume $d deleted.\n";
		}
	    }
	}
    }
}
