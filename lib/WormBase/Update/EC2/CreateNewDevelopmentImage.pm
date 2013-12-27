package WormBase::Update::EC2::CreateNewDevelopmentImage;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'create a new AMI of the development instance'
);

# Number of instances to launch; optionally supplied to constructor.
#has 'instance_count' => (
#    is => 'rw',
#    required => 1,
#    );

# Size of instances to launch; optionally supplied by contructor.
#has 'instance_type' => (
#    is => 'rw',
#    required => 1,
#    );

# The elastic IP address used for the qaqc instance.
#has 'ip_address' => (
#    is => 'ro',
#    default => '50.19.229.229',
#);

has 'user_data' => (
    is => 'ro',
    lazy_build => 1
    );

sub _build_user_data {
    my $self   = shift;
    
my $user_data = <<END;
#!/bin/bash

# Ensure that any future AMIs created from this instance 
# can also use user_data
insserv -d ec2-run-user-data

# Disable some services
# Is user-data executed AFTER services have launched?
/etc/init.d/jenkins stop

# Set a sensible hostname
hostname qaqc

# Remove the configuration file for the app.
rm -rf /usr/local/wormbase/wormbase.env

# Make sure that sudo continues to work.
printf "\n127.0.0.1   qaqc\n" >> /etc/hosts

# Git the repo
cd /usr/local/wormbase/website
git clone git@github.com:WormBase/website.git
mv website production
mkdir production/logs
cd production
git checkout production
git submodule init
git submodule update

END
;
    return $user_data;
}

sub run {
    my $self = shift;           
    my $instances = $self->_launch_instances();    
    $self->tag_instances({ instances   => $instances,
			   description => 'qaqc instance from AMI: ' . $self->core_image,
			   name        => 'wb-qaqc',
			   status      => 'qaqc',
			   role        => 'appserver',
			   source_ami  => $self->core_image,
			 });
    
    $self->tag_volumes({ instances   => $instances,
			 description => 'qaqc instance from AMI: ' . $self->core_image,
			 name        => 'wb-qaqc',  # this is the name root, appended with qualifier
			 status      => 'qaqc',
			 role        => 'appserver',
		       });
    

    # TODO: 2013.12.16
    # I should also delete the data mount. But I *can't* -- I need it for website-shared and databases
    # blech.
    $self->log->info("Deleting the data mount.");



    $self->associate_ip_address($instances->[0],$self->ip_address);
    
    $self->log->info("The qaqc instance has been launched.");
    $self->display_instance_metadata($instances);

}	    



sub _launch_instances  {
    my $self = shift;

    # Discover the build image. There should only be one.
    my $image   = $self->core_image();
    
    my $instance_count = $self->instance_count;
    my $instance_type  = $self->instance_type;
    
    $self->log->info("Found AMI ID $image built for " . $self->release . '.');
    $self->log->info("Launching $instance_count $instance_type instances...");
    
    my @instances = $image->run_instances(-min_count         => $instance_count,
					  -max_count         => $instance_count,
					  -key_name          => 'wormbase-development',
					  -security_group    => 'wormbase-development',
					  -instance_type     => $instance_type,
					  -placement_zone    => 'us-east-1d',
					  -shutdown_behavior => 'terminate',
					  -user_data         => $self->user_data,
					  -block_devices => [ '/dev/sdc=none' ],   # We don't want the FTP directory
#									       '/dev/sde=ephemeral0',
#									       '/dev/sdf=ephemeral1'],
	);
    
    # Wait until the instances are up and running.
    $self->log->info("Waiting for instances to launch...");
    my $ec2 = $self->ec2;
    $ec2->wait_for_instances(@instances);
    return \@instances;   
}






#!/usr/bin/perl

# Create a new core WormBase image (generated from the current development instance)

# From the existing development instance:
# 1. create a new image. 

# Why?  Why not simply not STOP the instance on create?
# 2. launch a new development instance
# 3. reassign the elastic IP address to it.
# 4. stop the old instance
# 5. Clean up.

# Create a NEW build image from a currently running instance
# tagged with Role:Build

use strict;
use VM::EC2;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new image of the current development instance.

Options:
  --release     required. The WSXXX version hosted on the instance.
                          Typically the version moving to production.

END

}

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);

# Discover the current QAQC environment instance.
# Hopefully it exists.
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

# Okay, we only have a single instance.
my $instance = $i[0];

my $date = `date +%Y-%m-%d`;
chomp $date;

# Now that I have the instance, create a new AMI from it with appropriate tags.
print STDERR "Creating a new image of $instance...\n";
my $image = $instance->create_image(-name        => "wb-development-$date",
				    -description => 'the wormbase development environment',
    );

# Wait until the production image is complete.
while ($image->current_status eq 'pending') {
    sleep 5;
}

# Add some tags.
$image->add_tags( Name        => "wb-core",
		  Description => "wormbase development image autocreated from $instance",
		  Status      => 'cored',
		  Role        => 'appserver',
		  Date        => $date,
		  Release     => $release,
		  Project     => 'WormBase',
		  Client      => 'OICR',
		  Image       => $image,
    );


tag_snapshots($image,$date);

print STDERR <<END

A new development image has been created with ID: $image.

You may wish to delete the old instance: $instance.

--

END
;


# Tag snapshots associated with this image.
# We fetch all snapshots, then look for those with a description
# matching our current image_id. (This could also be via a filter)
sub tag_snapshots {
    my ($image,$date) = @_;    
    my @all_snaps = $ec2->describe_snapshots();
    my @these_snapshots;
    foreach my $snapshot (@all_snaps) {
	if ($snapshot->description =~ /$image/) {  # taken here to be image_id.
	    push @these_snapshots,$snapshot;
	}
    }
    
    # Got 'em. Tag 'em.
    foreach my $snapshot (@these_snapshots) {
	print STDERR "\ttagging $snapshot...\n";
	my $id = $snapshot->snapshotId;
	
	# Name and description are dynamic based on size of the snapshot.	
	# This is hard-coded logic for now.
	my $size = $snapshot->size;  # Units?
	my ($name);
	if ($size < 20) {
	    # This is the root volume.
	    $name = 'root';
	} elsif ($size > 600) {
	    # FTP
	    $name = 'ftp';
	} else {
	    $name = 'data';
	}

	$ec2->add_tags(-resource_id => [ $id ],
		       -tag         => { Name        => "wb-core-$name",
					 Description => "$name volume for core image $image",
					 Status      => 'core',
					 Role        => 'appserver',
					 Release     => $release,
					 Project     => 'WormBase',
					 Client      => 'OICR',
					 Date        => $date,
					 Source_ami  => $image,
		       });	
    }
}







1;
