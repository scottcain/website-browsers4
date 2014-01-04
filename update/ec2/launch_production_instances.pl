#!/usr/bin/perl

# Launch new production instances from the "Tag:Status=production" webapp AMI.
use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::LaunchProductionInstances;
use Getopt::Long;

my ($release,$help,$instance_count,$instance_type);
GetOptions('release=s'     => \$release,
	   'help'          => \$help,
	   'instances=i'   => \$instance_count,
	   'type=s'        => \$instance_type,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--instances --type] 

Launch new instances of the core webapp AMI.

Options:
  --release     required. The WSXXX version of release to build.
  --instances   optional. Number of new prod instances to launch. Default: 1.
  --type        optional. Size of new instances to launch. Default: m1.large

END

}

$instance_count ||= 1;
$instance_type  ||= 'm1.large';

my $agent = WormBase::Update::EC2::LaunchProductionInstances->new(instance_count => $instance_count,
								  instance_type  => $instance_type,
								  release        => $release,
    );
$agent->execute();




