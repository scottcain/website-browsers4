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
    my $self    = shift;    
    my $release = $self->release;

    my $user_data = <<END;
#!/bin/bash

# Stop services
echo "stopping services..."
/etc/init.d/mysql stop
killall -9 sgifaceserver

# Remove old mounts
echo "removing old mounts..."
# Although MySQL databases are on RDS, I still need to unmount mysql so I can delete volume.
umount /var/lib/mysql
umount /var/log/mysql
umount /etc/mysql
umount /usr/local/wormbase/

# Ensure that any future AMIs created from this instance 
# can also use user_data
echo "ensuring that future AMIs created from this instance can use user-data..."
insserv -d ec2-run-user-data

# Format our new disk
echo "configuring new volume..."
mkfs.ext3 /dev/xvdg
mount /dev/xvdg /mnt/ebs1

################################################
# Move acedb to our new disk.
################################################
echo "setting up acedb/ ..."
mkdir /usr/local/wormbase/acedb
mkdir -p /mnt/ebs1/usr/local/wormbase/acedb
chown -R tharris:wormbase /mnt/ebs1/usr/local/wormbase
chmod 2775 /mnt/ebs1/usr/local/wormbase/acedb
cp -rp /mnt/ebs0/usr/local/wormbase/acedb/. /mnt/ebs1/usr/local/wormbase/acedb/.
mount --bind /mnt/ebs1/usr/local/wormbase/acedb /usr/local/wormbase/acedb

################################################
# Set up directories on ephemeral storage and
# copy data over.
################################################
# /usr/local/wormbase/databases
echo "relocating databases to ephemeral storage..."
mkdir /usr/local/wormbase/databases
chown -R tharris:wormbase /usr/local/wormbase/databases
mkdir -p /mnt/ephemeral0/usr/local/wormbase/databases
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase/databases
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/databases
mount --bind /mnt/ephemeral0/usr/local/wormbase/databases /usr/local/wormbase/databases
cp -rp /mnt/ebs0/usr/local/wormbase/databases/$release /mnt/ephemeral0/usr/local/wormbase/databases/.

# tmp directory
echo "relocating temporary directory to ephemeral storage..."
mkdir /usr/local/wormbase/tmp
mkdir -p /mnt/ephemeral0/usr/local/wormbase/tmp
chown -R tharris:wormbase /mnt/ephemeral0/usr/local/wormbase
chmod 2775 /mnt/ephemeral0/usr/local/wormbase/tmp
mount --bind /mnt/ephemeral0/usr/local/wormbase/tmp /usr/local/wormbase/tmp

# /usr/local/wormbase/website
echo "relocating website/ to ephemeral storage..."
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

# MySql databases. These are now on RDS.
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
echo "configuring perllib..."
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
END
;
 
# TO DO: should send an email
# with hostname, etc. 
}

sub run {
    my $self = shift;           
    
    my $instances = $self->_launch_instances();
    my $image     = $self->production_image;

    $self->tag_instances({ instances   => $instances,
			   description => "production instance from AMI: $production_image",
			   name        => 'wb-webapp',
			   status      => 'production',
			   role        => 'webapp',
			   source_ami  => $self->image,
			 });

    $self->tag_volumes({ instances   => $instances,
			 description => "volume for production instance",
			 name        => 'wb-webapp',  # this is the name root
			 status      => 'production',
			 role        => 'webapp',
		       });
    $self->delete_data_volume($instances);

    $self->log->info("New production instances have been launched");
    $self->display_instance_metadata($instances);
}	    



sub _launch_instances  {
    my $self = shift;

    # Get the production image for this release. There should only be one.
    my $image   = $self->production_image();
    
    my $instance_count = $self->instance_count;
    my $instance_type  = $self->instance_type;
    
    $self->log->info("Found AMI ID $image built for " . $self->release . '.');
    $self->log->info("Launching $instance_count $instance_type instances...");
    
    my @instances = $image->run_instances(-min_count         => $instance_count,
					  -max_count         => $instance_count,
					  -key_name          => 'wormbase-webapp',
					  -security_group    => 'wormbase-production-webapp',
					  -instance_type     => $instance_type,
					  -placement_zone    => 'us-east-1d',
					  -shutdown_behavior => 'terminate',
					  -user_data         => $self->user_data,
					  -block_devices => [ '/dev/sde=ephemeral0',
							      '/dev/sdf=ephemeral1',
							      '/dev/sdg=:50:true'],
	);
    
    # Wait until the instances are up and running.
    $self->log->info("Waiting for instances to launch...");
    my $ec2 = $self->ec2;
    $ec2->wait_for_instances(@instances);
    return \@instances;   
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
    

1;
