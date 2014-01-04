#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::CreateNewProductionImage;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help'      => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new production image from the currently running qaqc *instance*.

Options:
  --release     required. The WSXXX version of release to build.

END

}

my $agent = WormBase::Update::EC2::CreateNewProductionImage->new(release => $release);
$agent->run();

