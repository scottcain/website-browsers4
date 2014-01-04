package WormBase::Update::EC2::CleanupInstances;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'cleanup temporary instances and associated volumes',
    );

has 'status' => (
    is => 'rw');

sub run {
    my $self = shift;           

    my $status = $self->status;

    # Get all the current "status" instances
    my $instances = $self->get_instances({'tag:Status'  => $status,
					  'tag:Release' => $self->release});

    foreach my $instance (@$instances) {
	$self->log->info("\tshutting down $instance");
	my $ec2 = $self->ec2;
	
	# Get all volumes. Delete them.
	# my @volumes = $ec2->describe_volumes(-filter=> { 'attachment.instance-id' => $instance } );	
	my @devices   = $instance->blockDeviceMapping;
	
	# Terminate the instance.
	$ec2->terminate_instances($instance);
	$ec2->wait_for_instances([$instance]);
	$self->log->info("$instance has been terminated; deleting volumes...");
	sleep 60;  # just to be sure; termination can be SLOOOOW and wait_for doesn't seem to trap.

	foreach my $device (@devices) {
	    my $volume    = $device->volume;
	    my $volume_id = $device->volumeId;

	    my $result = $ec2->delete_volume($volume_id);
	    if ($result) {
		$self->log->info("\t$volume has been deleted"); 
	    } else {
		$self->log->warn("There was a problem deleting $volume");
	    }
	}

    }    
    $self->log->info("cleaning up $status instances: complete");
}


1;
