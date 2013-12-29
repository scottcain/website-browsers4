#!/usr/bin/perl

# Create a NEW build image from a currently running instance
# tagged with Role:Build

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::CreateNewDevelopmentImage;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new image for the currently running development *instance*.

Options:
  --release     required. The WSXXX version of release to build.

END

}

my $agent = WormBase::Update::EC2::CreateNewDevelopmentImage->new();
#$agent->run();

