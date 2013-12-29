package WormBase::Update::EC2::LaunchQAQCInstances;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'launch QAQC instances from the current development image',
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

# The elastic IP address used for the qaqc instance.
has 'ip_address' => (
    is => 'ro',
    default => '50.19.229.229',
);

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
git clone git\@github.com:WormBase/website.git
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




1;
