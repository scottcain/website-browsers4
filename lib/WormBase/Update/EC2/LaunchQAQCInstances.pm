package WormBase::Update::EC2::LaunchQAQCInstances;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'launch QAQC instances from the current qaqc image',
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


has 'role' => (
    is => 'rw',
    default => 'webapp',
    );

has 'user_data' => (
    is => 'ro',
    lazy_build => 1
    );

sub _build_user_data {
    my $self   = shift;
    
my $user_data = <<END;
#!/bin/bash

insserv -d ec2-run-user-data
rm -rf /usr/local/wormbase/wormbase.env
/etc/init.d/rserve-startup 
rm -rf /etc/mysql/my.cnf
cd /var/lib/jenkins/jobs/staging_build/workspace
sudo -u jenkins /usr/local/bin/uglifyjs root/js/wormbase.js -o root/js/wormbase.min.js

END
;
    return $user_data;

=pod


#!/bin/bash

# Ensure that any future AMIs created from this instance 
# can also use user_data
echo "ensuring that future AMIs created from this instance can use user-data..."
insserv -d ec2-run-user-data

# Disable some services
# Is user-data executed AFTER services have launched?
#echo "stopping services..."
#/etc/init.d/jenkins stop

# Set a sensible hostname
# echo "setting hostname..."
# hostname qaqc

# Make sure that sudo continues to work.
# printf "127.0.0.1   qaqc\n" >> /etc/hosts

# Git the repo
#echo "Fetching the git repository..."
#cd /usr/local/wormbase/website
#git clone git\@github.com:WormBase/website.git
#mv website production
#mkdir production/logs
#cd production
#git checkout production
#git submodule init
#git submodule update

# Remove the configuration file for the app.
echo "removing the wormbase.env file..."
rm -rf /usr/local/wormbase/wormbase.env

echo "copying over the rserve init script..."
cp -r /usr/local/wormbase/website-admin/init/rserve-startup /etc/init.d/rserve-startup
/etc/init.d/rserve-startup 

# What else do I need to do for qaqc? start precaching?

# Remove an auotcreated my.cnf file that tends to break mysql
rm -rf /etc/mysql/my.cnf

# Minimize JS
cd /var/lib/jenkins/jobs/staging_build/workspace
sudo -u jenkins /usr/local/bin/uglifyjs root/js/wormbase.js -o root/js/wormbase.min.js

echo "Preconfiguration is complete!"
#echo "You should now :"
#echo "    > saceclient localhost -port 2005  -- to start sgifaceserver"
#echo "    > cd /usr/local/wormbase/website/production ; ./script/wormbase-daemon.sh -- to start webapp"

#IP=`GET http://169.254.169.254/latest/meta-data/local-ipv4`
#echo "local private IP: \$IP"

END

=cut

}

sub run {
    my $self = shift;           
    my $instances = $self->_launch_instances();    

    $self->tag_instances({ instances   => $instances,
			   description => 'qaqc instance from AMI: ' . $self->qaqc_image,
			   name        => 'qaqc',
			   status      => 'qaqc',
			   role        => 'webapp',
			   source_ami  => $self->qaqc_image,
			 });
    
    $self->tag_volumes({ instances   => $instances,
			 description => 'qaqc instance from AMI: ' . $self->qaqc_image,
			 name        => 'qaqc',  # this is the name root, appended with qualifier
			 status      => 'qaqc',
			 role        => 'webapp',
		       });
    
#    $self->log->info("Deleting the data mount.");
#    $self->delete_data_volume();
    
    $self->log->info("A qa/qc instance has been launched.");
    $self->display_instance_metadata($instances);
}	    



sub _launch_instances  {
    my $self = shift;

    # Discover the build image. There should only be one.
    my $image   = $self->qaqc_image();
    
    my $instance_count = $self->instance_count;
    my $instance_type  = $self->instance_type;
    
    $self->log->info("Found AMI ID $image built for " . $self->release . '.');
    $self->log->info("Launching $instance_count $instance_type instances...");

    my $role = $self->role;

    # No FTP mount but enable ephemeral storage
    my @mounts = ('/dev/sdc=none',
		  '/dev/sde=ephemeral0',
		  '/dev/sdf=ephemeral1');
    

    # ... or modencode directory for webapp instances    
    # Lets just retain the modencode mount for now for all instances.
    #    if ($role eq 'webapp') {
    #	push @mounts,'/dev/sdg=none',
    #    }

    my @instances = $image->run_instances(-min_count         => $instance_count,
					  -max_count         => $instance_count,
					  -key_name          => 'wormbase-development',
					  -security_group    => 'wormbase-development',
					  -instance_type     => $instance_type,
					  -placement_zone    => 'us-east-1d',
					  -shutdown_behavior => 'terminate',
					  -user_data         => $self->user_data,
					  -block_devices     => \@mounts, 

	);
        
    # Wait until the instances are up and running.
    $self->log->info("Waiting for instances to launch...");
    my $ec2 = $self->ec2;
    $ec2->wait_for_instances(@instances);
    return \@instances;   
}


1;
