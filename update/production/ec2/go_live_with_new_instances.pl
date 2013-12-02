#!/usr/bin/perl

# Once the new production instances have launched
# toggle the elastic IPs that are pointing to them.

# This is NOT FINISHED. Due with WS240 rollout.
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

Go "live" with new instances of the webapp.

Options:
  --release     required. The WSXXX version of release to build.

END

}

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint   => 'http://ec2.amazonaws.com',
		       -print_error => 1);

# Get the NEW production instances
my @i = $ec2->describe_instances({'tag:Status' => 'production',				  
				  'tag:Role'    => 'webapp',
				  'tag:Release' => $release
				 });

# 1. Disocciate address from OLD instances

# 2. Reassociate to NEW instances.


# Fetch the INTERNAL ip of the instances from instance meta-data
# This will be used by nginx
    


