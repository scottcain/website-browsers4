#!/usr/bin/perl

# Create a NEW build image from a currently running instance
# tagged with Role:Build

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::EC2;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new build image for the currently running build *instance*.

Options:
  --release     required. The WSXXX version of release to build.

END

}


my $agent = WormBase::Update::EC2->new();

my $ec2;





# Connect to EC2 ; access_key and secret_key provided by ENV
#my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
#		       -print_error => 1);




# Discover the current QAQC environment instance.
# Hopefully it exists.
my @i = $ec2->describe_instances({'tag:Status' => 'build' });

if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple build instances running at the moment. 
	There should only be one. Please kill some of the extras and re-run.
	The running instances are:

END
print join("\t\n",@i);
    die;
}

# Okay, we only have a single instance.
my $instance = $i[0];

my $date = `date +%Y-%m-%d`;
chomp $date;

# Now that I have the instance, create a new AMI from it with appropriate tags.
my $image = $instance->create_image(-name        => "wb-build-$date",
				    -description => 'stripped down environment for building new WormBase releases',
    );

# Wait until the production image is complete.
while ($image->current_status eq 'pending') {
    sleep 5;
}

# Add some tags.
$image->add_tags( Name        => "wb-build",
		  Description => "wormbase build image autocreated from $instance",
		  Status      => 'build',
		  Role        => 'build',
		  Date        => $date,
		  Release     => $release,
		  Project     => 'WormBase',
		  Client      => 'OICR',
    );


# Tag snapshots: see production/create_new_development_image.pl

print STDERR <<END

A new build image has been created with ID: $image.

You may wish to delete the old instance: $instance.

--

END
;

    


