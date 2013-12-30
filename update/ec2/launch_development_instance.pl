#!/usr/bin/perl

# Instead of launching a new instance, maybe a better strategy is to 
# simply UPDATE the tags on it.


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

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::LaunchQAQCInstances;
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


my $agent = WormBase::Update::EC2::LaunchDevelopmentInstance->new(instance_count => $instance_count,
							    instance_type  => $instance_type,
							    release        => $release,
    );
$agent->execute();


# ------



swap_ip_addresses($ec2,$instances[0],$old_instance);

print STDERR "Cleaning up old resources\n";

# TODO
# clean_up_resources();



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








