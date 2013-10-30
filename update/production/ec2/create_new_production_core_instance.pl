#!/usr/bin/perl

# NOTE!
# The QAQC instance needs to have a tag of Status = 'qaqc';

# This ALSO needs to tag snapshots of the resulting AMI


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

Create a new AMI of the QAQC instance.

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

# Now that I have the qa/qc instance, create the new production AMI 
# from it. This will snapshot all EBS volumes too, which we can use
# to quickly configure new instances.
my $production_image = $qaqc_instance->create_image(-name        => "wb-prod-$release",
						    -description => "WormBase Release: $release",
						    -no_reboot   => 1);

# Wait until the production image is complete.
while ($production_image->current_status eq 'pending') {
    sleep 5;
}

# Add some tags.
$production_image->add_tags( Name        => "$release-wb-qaqc-to-production-webapp"
			     Description => "webapp production autoimage from instance: $qaqc_instance",
			     Status      => 'production',
			     Role        => 'webapp',			     
			     Release     => $release,
			     Project     => "WormBase",
			     Client      => 'OICR',
    );

print STDERR "A new production image has been created with ID: $production_image\n";

    


