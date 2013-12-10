#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::LaunchBuildInstance;
use Getopt::Long;

my ($release,$help,$instance_count,$instance_type);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
	   'instances=i'   => \$instance_count,
	   'type=s'        => \$instance_type,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--instances --type] 

Start a new build instance and prepopulate it with data.

Options:
  --release     required. The WSXXX version of release to build.
  --instances   optional. Number of new prod instances to launch. Default: 1.
  --type        optional. Size of new instances to launch. Default: m1.xlarge

END

}


my $agent = WormBase::Update::EC2::LaunchBuildInstance->new();
if ($instance_count) { $agent->instance_count($instance_count); }
if ($instance_type)  { $agent->instance_type($instance_type);   }

$agent->execute();




