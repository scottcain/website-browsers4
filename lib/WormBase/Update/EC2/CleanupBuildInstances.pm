package WormBase::Update::EC2::CleanupBuildInstances;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'cleanup build instances and associated volumes',
    );

sub run {
    my $self = shift;           
    
    # Get all the current build instances
    my $instances = $self->get_instances('build');
    foreach my $instance (@$instances) {
	$self->log->info("\tshutting down $instance");
	my $ec2 = $self->ec2;
	
	# Get all volumes. Some are set to delete on termination.
	my @volumes = $ec2->describe_volumes(-filter=> { 'attachment.instance-id' => $instance } );
	
	# Terminate the instance.
	$ec2->terminate_instances($instance);
	$ec2->wait_for_instances([$instance]);
	sleep 60;  # Just to be sure that we are terminated.
	
	$self->log->info("$instance has been terminated; deleting volumes");
	foreach my $volume (@volumes) {
	    my $result = $ec2->delete_volume($volume);
	    $self->log->info("\t$volume has been deleted");
	}
    }    
    $self->log->info("cleaning up build instances: complete");
}


1;
