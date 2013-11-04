#!/usr/bin/perl

use strict;
use VM::EC2;
use Getopt::Long;

my ($release,$ami_id,$help);
GetOptions('release=s' => \$release,
	   'ami_id=s'  => \$ami_id,
	   'help=s'    => \$help,
    );

if ($help || (!$release && !$ami_id)) {
    die <<END;

Usage: $0 --release WSXXX --ami_id ami-4e50f127

Launch a new instance of the WormBase site on the Amazon cloud.
By default will use an m1.large instance.

END
;
}


my $access_key = $ENV{EC2_ACCESS_KEY};
my $secret_key = $ENV{EC2_SECRET_KEY};

# get new EC2 object
my $ec2 = VM::EC2->new(-access_key => $access_key,
		       -secret_key => $secret_key,
		       -endpoint   => 'http://ec2.amazonaws.com') or die "$!";

# The core image ID is hard-coded here. But it will change from release to release.
# Need to discover what it is.
my $image       = $ec2->describe_images($ami_id);
print "Found image $ami_id: " . $image->name . ' (' . $image->description . ")\n";

my $user_data = write_user_data_file();
print $user_data;

my $instance    = $image->run_instances(-instance_type     => 'm1.large',
					-availability_zone => 'us-east-1d',
					-user_data         => $user_data,
    );
#					-user_data         => "/tmp/new_instance_$release.sh",

# wait for both instances to reach "running" or other terminal state
$ec2->wait_for_instances($instance);

my $instance_id = $instance->instanceId; 
my $hostname    = $instance->dnsName;

print "We have launched a new instance!  It is at $hostname (instance ID: $instance_id)\n";


# Get a list of all available volumes
my @volumes = $ec2->describe_volumes({status => 'available'});
for my $volume (@volumes) {
    my $tags      = $volume->tags;
    my $volume_id = $volume->volumeId;    
    if ($tags->{Version} eq $release) {	
	my $a = $volume->attach($instance_id,'/dev/sdg');
	while ($a->current_status ne 'attached') {
	    sleep 2;
	}
	print "volume $volume_id is attached to $instance_id and ready to go\n";

	print "Waiting 60 seconds before trying to connect...\n";
	sleep 60;	

# Detach the volume from the instance
#	my $attachment = $volume->detach({-instance_id => $instance_id });
#	while ($attachment->current_status ne 'detached') {
#	    sleep 2;
#	}
	
    }
}



# Dump out the user_data_file for delivery to the new instance.
# This will be executed at system launch.
sub write_user_data_file {
#    open OUT,">/tmp/new_instance_$release.sh" or die;
#    print OUT <<END;
    my $user_data = <<END;
#!/bin/bash

set -x

# This init script is run when launching a new instance.
# It will automatically be run as the root user.

# Mount my EBS volume
mount /dev/xvdg /mnt/ebs
    
# Create some target directories on ephemeral storage.
mkdir /mnt/ephemeral0/wormbase
chmod 2775 /mnt/ephemeral0/wormbase
mkdir /mnt/ephemeral1/mysql
chown mysql:mysql /mnt/ephemeral1/mysql
chmod 2775 /mnt/ephemeral1/mysql
    
# Create some symbolic mounts
mount /usr/local/wormbase /mnt/ephemeral0/wormbase
mount /var/lib/mysql /mnt/ephemeral1/mysql
    
# Copy EBS contents to ephemeral storage
cp -rp /mnt/ebs/wormbase/* /mnt/ephemeral0/wormbase/.
cp -rp /mnt/ebs/mysql/* /mnt/ephemeral1/mysql/.
    
# Unmount the volume
umount /mnt/ebs

saceclient localhost -port 2005
cd /usr/local/wormbase/website/production
./script/wormbase-init.sh start
END
    ;
#close OUT;
return $user_data;
}
