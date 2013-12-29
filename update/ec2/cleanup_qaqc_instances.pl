#!/usr/bin/perl

# FOR THIS TO WORK:
# The QAQC instance needs to have a tag of Status = 'qaqc';

use strict;
use VM::EC2;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--instances --type] 

Clean up QA/QC resources for a given release.

Options:
  --release     required. The WSXXX version of release to build.

END

}

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);

# Discover the current QAQC environment instance.
# Hopefully it exists.
my @i = $ec2->describe_instances({'tag:Status' => 'qaqc' });

if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple qa/qc instances running at the moment. 
	There should only be one. Please kill some of the extras and re-run.
	The running instances are:

END
print join("\t\n",@i);
    die;
}

# Okay, we only have a single qaqc instance.
my $qaqc_instance = $i[0];


cleanup_qaqc_instance($qaqc_instance);


# Clean up the qa/qc instance.
sub cleanup_qaqc_instance {
    my $instance = shift;

    # Get the primary data volume attached to this instance FIRST.
    # The root volume deletes on termination.
    # This hard-coded for now - the volume we are looking for is mounted at /dev/sdb
    my @volumes = $ec2->describe_volumes(-filter=> { 'attachment.instance_id' => $instance,
						     'attachment.device'      => '/dev/sdb'  });
    
    # This should be a single volume
    my $volume = $volumes[0];

    # Terminate the QAQC instance.
    $ec2->terminate_instances($instance);
    my $status = $ec2->wait_for_instances([$instance]);

    # We're terminated. Let's delete the data volume now.
    if ($status eq 'terminated') {
	my $result = $ec2->delete_volume($volume);
    }           
}
