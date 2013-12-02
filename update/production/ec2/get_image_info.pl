#!/usr/bin/perl

use strict;
use VM::EC2;
use Getopt::Long;

my ($format,$help,$status);
GetOptions('format=s'     => \$format,
	   'help=s'        => \$help,
	   'status=s'      => \$status,
    );


if ($help) {
    die <<END;
    
Usage: $0

Get information on all or specific sets of instances.

Options:
  --status      optional. One of [build|development|production]
                          If not provided defaults to listing ALL instances.  
  --format      short || long. Defaults to short listing.

END

}

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);


my @i;
if (!$status) {
    @i = $ec2->describe_instances();
    print STDERR "Listing all currently running instances...\n\n";
} else {
    @i = $ec2->describe_instances({'tag:Status' => $status });
    print STDERR "The following $status instances currently exist...\n\n";
}



foreach my $i (@i) {
    
    my $id         = $i->instanceId; 
    my $type       = $i->instanceType;
    my $state      = $i->instanceState;
    my $status     = $i->current_status;
    my $zone       = $i->availabilityZone;
    my $launched   = $i->launchTime;
    my @groups     = $i->groups;
    my $tags       = $i->tags;

    # Network information
    my $hostname   = $i->dnsName;
    my $private_ip = $i->privateIpAddress;
    my $public_ip  = $i->ipAddress;
    
    # EBS volumes
    # my $block_dev  = $i->blockDeviceMapping;

    # Pepper our environment
    system('export WBSERVER$c="' . $hostname . '"');

    if ($format eq 'short') {
	print "  $hostname ($tags->{Role}; $state)\n";
    } else {
	print "  Instance: $id ($hostname)\n";
	print "\tprivate ip address: $private_ip\n";
	print "\t public ip address: $public_ip\n";
	print "\t    instance type : $type\n";
	print "\t             zone : $zone\n";
	print "\t            state : $state\n";
	print "\t           status : $status\n";
	print "\t              TAGS\n";
	foreach (sort keys %$tags) { 
	    print "\t                    $_ : $tags->{$_}\n";
	}
	
	print "\t              EBS mounts\n";
	my @devices = $i->blockDeviceMapping;
	foreach my $d (@devices) {
	    my $virtual_device = $d->deviceName;
	    print "\t                    $d : $virtual_device\n";
	}
	print "\n";
    }
}

print "\n";	
    


