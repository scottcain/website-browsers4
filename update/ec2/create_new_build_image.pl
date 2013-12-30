#!/usr/bin/perl

# Create a NEW build image from a currently running instance
# tagged with Role:Build

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::CreateNewBuildImage;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help'          => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new build image for the currently running build *instance*.

Options:
  --release     required. The WSXXX version of release to build.

END

}

my $agent = WormBase::Update::EC2::CreateNewBuildImage->new(release => $release);
$agent->execute();

