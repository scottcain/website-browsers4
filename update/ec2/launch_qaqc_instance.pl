#!/usr/bin/perl

# Once we've created a new development image,
# launch a new version of it for QAQC/prebake

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::LaunchQAQCInstances;
use Getopt::Long;

my ($release,$help,$instance_count,$instance_type);
GetOptions('release=s'     => \$release,
	   'help'          => \$help,
	   'instances=i'   => \$instance_count,
	   'type=s'        => \$instance_type,
    );

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Launch a new qaqc instance from the qaqc image.

Options:
  --release     required. The WSXXX release to launch.
  --instances   optional. Number of instances to launch. Default: 1.
  --type        optional. Size of instances to launch. Default: m3.xlarge

END
}

$instance_count ||= 1;
$instance_type  ||= 'm3.xlarge';

my $agent = WormBase::Update::EC2::LaunchQAQCInstances->new(instance_count => $instance_count,
							    instance_type  => $instance_type,
							    release        => $release,
    );
$agent->execute();

1;
