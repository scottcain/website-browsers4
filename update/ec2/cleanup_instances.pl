#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::CleanupInstances;
use Getopt::Long;

my ($release,$help,$status);
GetOptions('release=s'     => \$release,
	   'hels'          => \$help,
	   'status=s'      => \$status,
    );

if ($help || (!$release && !$status)) {
    die <<END;
    
Usage: $0 --release WSXXX --status [STATUS]

Clean up instances/volumes for a specified release and status.

Options:
  --release     required. The WSXXX version of release to build.
  --status      required. From Tag:Status. Typically: build/qaqc

END

}

my $agent = WormBase::Update::EC2::CleanupInstances->new(release => $release,
							 status  => $status );
$agent->execute();

