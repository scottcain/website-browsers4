package WormBase::Update::EC2::CreateNewProductionImage;

# From a single running QAQC instance, create a new production AMI
# for the current release.

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'create a new AMI of a single QAQC instance'
);

sub run {
    my $self = shift;           

    # Discover the current qaqc environment instance.
    my $instances = $self->get_instances({'tag:Status'  => 'qaqc',					
					  'tag:Release' => $self->release});
    
    if (@$instances > 1) { 
	$self->log->warn("
        Um. 
    	    There seem to be multiple qaqc instances running at the moment. 
 	    There should only be one. Please kill some of the extras and re-run.
	    The running instances are:
	    ");
	
	$self->log->logdie(join("\t\n",@$instances));
    }
    
    # Okay, we only have a single instance.
    my $instance = $instances->[0];
    
    # Now that I have the instance, create a new AMI from it with appropriate tags.
    # The AMI Name *must* be unique, but not the "Tag:Name"
    my $image = $instance->create_image(-name        => 'wb-production-' . $self->release,
					-description => 'wormbase production AMI',
	);
    
    # Wait until the production image is complete.
    while ($image->current_status eq 'pending') {
	sleep 5;
    }
    
    # Add some tags to the AMI and its backing snapshots.
    $self->tag_images({ image       => $image,
			description => "wormbase production AMI autocreated from $instance",
			name        => 'wb-production',
			status      => 'production',
			role        => 'webapp',
		      });
    
    $self->tag_snapshots({ images  => $image,
			   name    => 'wb-production',
			   status  => 'production',
			   role    => 'webapp',
			 });
    
    $self->log->info("Creating a new production image: finished. Image id: $image");  
}    

1;
