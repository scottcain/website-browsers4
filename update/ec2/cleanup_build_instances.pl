#!/usr/bin/perl

# FOR THIS TO WORK:
# The QAQC instance needs to have a tag of Status = 'qaqc';

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::CleanupBuildInstances;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Clean up build resources for a given release.

Options:
  --release     required. The WSXXX version of release to build.

END

}

my $agent = WormBase::Update::EC2::CleanupBuildInstances->new(release => $release);
$agent->execute();

