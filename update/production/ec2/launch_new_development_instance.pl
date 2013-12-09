#!/usr/bin/perl

# Once a new development image has been created:
# 1. Fetch the ID of the current development instance
# 2. Get the ID of the desired development image (typically just created)
# 3. Launch a new instance of it.

# 1. Launch a new instance of it.
# 2. 
# launch a new instance of it. Swap EIPs with the 
# old one, verify the new one works.
# Shut down the old instance.
# Remove the old instance and associated volumes.
# Remove the old image and associated snapshots.

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
    
Usage: $0 --release WSXXX

Launch a new development instance, kill the old, and clean up resources.

Options:
  --release     required. The WSXXX development release to launch.
  --instances   optional. Number of new prod instances to launch. Default: 1.
  --type        optional. Size of new instances to launch. Default: m1.xlarge

END

}

$instance_count ||= 1;
$instance_type  ||= 'm1.xlarge';

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);


# Get the CURRENT dvelopment instance.
my $old_instance = get_current_development_instance($ec2);

# Fetch the image for the provided release.
my $image = get_development_image($release);

# Launch an instance of the image.
my @instances = launch_instances($image);

# Wait until the instance(s) are available.
print STDERR "\t waiting for instances...\n";
$ec2->wait_for_instances(@instances);

tag_instances(\@instances);
tag_volumes(\@instances);

print STDERR "New development instance(s) have been launched. They are:\n\n";
display_instance_metadata(\@instances);

swap_ip_addresses($ec2,$instances[0],$old_instance);

print STDERR "Cleaning up old resources\n";

# TODO
# clean_up_resources();



# --------------------
sub swap_ip_addresses {
    my ($ec2,$new_instance,$old_instance) = @_;
    
    print STDERR "Swapping out the elastic IP address of the old instance...";
    
    # The Elastic IP of the old development instance.
    my $elastic_ip  = $old_instance->ipAddress;
    
    # Dissociate the elastic IP.
    my $disassociate = $ec2->disassociate_address($elastic_ip);

    # Did we successfully disassociate? The reassociate to new instance.
    if ($disassociate) {
	my $reassociate = $ec2->associate_address($elastic_ip => $new_instance);
	if ($reassociate) {
	    print STDERR "Successfully associated $elastic_ip to $new_instance...\n";
	}
    }
}
 
# To-do.  
sub clean_up_resources {
    my $instance = shift;

    # 1. Shut down the instance
    
    # 2. Delete volumes associated with it

    # 3. Delete the old image

    # 4. Delete old snapshots.

}




sub tag_volumes {
    my $instances = shift;    
    print STDERR "Tagging volumes with metadata...\n";

    my $date = `date +%Y-%m-%d`;
    chomp $date;

    my $c = 0;
    foreach my $instance (@$instances) {
	# EBS volumes. There should only be one per instance.
	my @devices  = $instance->blockDeviceMapping; # a hashref
	$c++;

	foreach  my $d (@devices) {
	    my $virtual_device = $d->deviceName;
#	    my $snapshot_id    = $d->snapshotId;
#	    my $delete         = $d->deleteOnTermination;     
	    
	    # Need the actual volume; cannot add tags to block device mappings
	    my $volume      = $d->volume;
	    my $volume_size = $volume->size;

	    # Name and description are dynamic based on size of the snapshot.	
	    # This is hard-coded logic for now.
	    my ($name);
	    if ($volume_size < 20) {
		# This is the root volume.
		$name = 'root';
	    } elsif ($volume_size > 600) {
		# FTP
		$name = 'ftp';
	    } else {
		$name = 'data';
	    }

	    $ec2->add_tags(-resource_id => [ $volume ],
			   -tag         => { Name        => "wb-development-$name",
					     Description => "name volume for $instance $release",
					     Status      => 'development',
					     Role        => "development",
					     Release     => $release,				     
					     Project     => 'WormBase',
					     Client      => 'OICR',
					     Date        => $date,
					     Attachment  => "$instance:$virtual_device",
			   });
	}
	
    }
}

sub tag_instances {
    my $instances = shift;

    print STDERR "Tagging instances with some metadata...\n";

    my $date = `date +%Y-%m-%d`;
    chomp $date;

    my $c = 0;
    foreach my $instance (@$instances) {
	$c++;
	$ec2->add_tags(-resource_id => [ $instance ],
		       -tag         => { Name        => "wb-development",
					 Description => "development instance from AMI: $image",
					 Status      => 'development',
					 Role        => 'dev-server',
					 Release     => $release,				     
					 Project     => 'WormBase',
					 Client      => 'OICR',
					 Date        => $date,
		       });	
    }
}






sub display_instance_metadata {
    my $i = shift;
    
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
	print "\n\n";
    }
}


# Fetch the image for the provided relase.
sub get_development_image {
    my $release = shift;
        
    print STDERR "Fetching the AMI for development:$release...\n";
    
    my @i = $ec2->describe_images({'tag:Release' => $release,
				   'tag:Status'  => 'development'});
    
    if (@i > 1) { 
	print STDERR <<END;

        Um. 
	There seem to be multiple development AMIs. There can be only one. They are:

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
    
    my $image = $i[0];
    
    print STDERR "Found the development image for $release: $image...\n";
    return $image;
}

sub get_current_development_instance {
    my $ec2 = shift;

    print STDERR "Fetching current development instance...\n";
    
# Discover the current development instance.
# Hopefully it exists. We assume there is only one.
    my @i = $ec2->describe_instances({'tag:Status'     => 'development',
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
    
	display_instance_metadata(\@i);
	die;
    }

# Okay, we only have a single instance.
    my $instance = $i[0];
    print STDERR "\t found one. It's details are:\n";
    display_instance_metadata([$instance]);
    return $instance;
}

   
sub launch_instances {
    my $image = shift;

    print STDERR "Launching $instance_count $instance_type instances of $image...\n";

my $user_data = <<END;
#!/bin/bash

# Ensure that any future AMIs created from this instance 
# can also use user_data
insserv -d ec2-run-user-data

END
;

    my @instances = $image->run_instances(-min_count => $instance_count,
					  -max_count => $instance_count,
					  -key_name  => 'wormbase-development',
					  -security_group => 'wormbase-development',
					  -instance_type  => $instance_type,
					  -placement_zone => 'us-east-1d',
					  -shutdown_behavior => 'terminate',
					  -user_data         => $user_data,
	);
    
    return @instances;
}
