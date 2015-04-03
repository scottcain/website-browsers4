package WormBase::Update::EC2::CreateNewQAQCImage;

# Create a new qaqc WormBase image (generated from the current development instance)

# From the existing development instance:
# 1. create a new image. 

# Why?  Why not simply not STOP the instance on create?
# 2. launch a new development instance
# 3. reassign the elastic IP address to it.
# 4. stop the old instance
# 5. Clean up.

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'create a new AMI of the development instance'
);

sub run {
    my $self = shift;           

    # Get the current development instance
    my $instances = $self->get_instances({'tag:Status'  => 'development',					
					  'tag:Release' => $self->release});
    
    if (@$instances > 1) { 
	$self->log->warn("
        Um. 
    	    There seem to be multiple development instances running at the moment. 
 	    There should only be one. Please kill some of the extras and re-run.
	    The running instances are:
	    ");
	
	$self->log->logdie(join("\t\n",@$instances));
    }
    
    # Okay, we only have a single instance.
    my $instance = $instances->[0];
    $self->log->logdie("no development instance found!") unless $instance;
    
    # Now that I have the instance, create a new AMI from it with appropriate tags.
    # The AMI Name *must* be unique.
    my $image = $instance->create_image(-name         => "qaqc-" . $self->release,
					-description  => 'image created from the WormBase dev environment',
					-no_reboot    => 1, );
    
    # Wait until the production image is complete.
    while ($image->current_status eq 'pending') {
	sleep 5;
    }
    
    # Add some tags to the AMI and its backing snapshots.
    $self->tag_images({ image       => "$image",
			description => "wormbase qaqc image autocreated from $instance",
			name        => 'qaqc',
			status      => 'qaqc',
			role        => 'webapp',
		      });
 
    # This does NOT work -- especially if I have created multiple AMIs from the same instance.
    $self->tag_snapshots({ images => "$image",
			   name   => 'wb-qaqc',
			   status => 'qaqc',
			   role   => 'webapp',
			 });
    
    $self->log->info("Creating a new image from development: finished. Image id: $image");  
}    

1;
