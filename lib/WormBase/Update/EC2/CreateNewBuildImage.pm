package WormBase::Update::EC2::CreateNewBuildImage;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'create a new AMI of a running build instance',
    );

sub run {
    my $self = shift;    
    
    # Discover the current build environment instance.
    my $instances = $self->get_instances({'tag:Status'  => 'build',
					  'tag:Release' => $self->release});
    
    # There should only be one.
    if (@$instances > 1) { 
	$self->log->warn("
        Um. 
	    There seem to be multiple build instances running at the moment. 
	    There should only be one. Please kill some of the extras and re-run.
	    The running instances are:
	    ");
	
	$self->log->logdie(join("\t\n",@$instances));
    }
    
    # Okay, we only have a single instance.
    my $instance = $instances->[0];
        
    # Now that I have the instance, create a new AMI from it with appropriate tags.
    # AMI Name must be unique
    my $image = $instance->create_image(-name        => 'wb-build-' . $self->release,
					-description => 'the wormbase build environment',
	);
    
    # Wait until the production image is complete.
    while ($image->current_status eq 'pending') {
	sleep 5;
    }
    
    # Add some tags to the AMI and its backing snapshots.
    $self->tag_images({ image       => $image,
			description => "wormbase build image autocreated from $instance",
			name        => 'wb-build',
			status      => 'build',
			role        => 'build',
		      });
    
    $self->tag_snapshots({ image  => $image,
			   name   => 'wb-build',
			   status => 'build',
			   role   => 'webapp',
			 });
    
    $self->log->info("Creating a new build image: finished. Image id: $image");
}

1;

