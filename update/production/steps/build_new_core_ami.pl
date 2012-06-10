#!/usr/bin/perl

use strict;
use VM::EC2;

my $access_key = $ENV{EC2_ACCESS_KEY};
my $secret_key = $ENV{EC2_SECRET_KEY};

# get new EC2 object
my $ec2 = VM::EC2->new(-access_key => $access_key,
		       -secret_key => $secret_key,
		       -endpoint   => 'http://ec2.amazonaws.com') or die "$!";

# find existing volumes that are available
#my @volumes = $ec2->describe_volumes({status=>'available'});
#print @volumes;

# fetch the Core WormBase AMI.
my $image = $ec2->describe_images('ami-e8bf1e81');
my $name  = $image->name;
my $state   = $image->imageState;
my $owner   = $image->imageOwnerId;
my $rootdev = $image->rootDeviceName;
my @devices = $image->blockDeviceMapping;
my $tags    = $image->tags;

print "name\t$name\n";
print "state\t$state\n";
print "owner\t$owner\n";
print "rootdev\t$rootdev\n";

