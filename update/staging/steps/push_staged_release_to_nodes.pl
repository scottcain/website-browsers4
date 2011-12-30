#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PushStagedReleaseToNodes;
use Getopt::Long;

my ($release,$target,$help);
GetOptions('release=s' => \$release,
	   'target=s'  => \$target,
	   'help=s'    => \$help);

if ($help || (!$target && !$release)) {
    die <<END;
    
Usage: $0 --target [development|mirror|production] --release WSXXX

Push a staged release to other environments.

END
;
}

my $agent = WormBase::Update::Staging::PushStagedReleaseToNodes->new({ release => $release,
								       target  => $target,
									});
$agent->execute();
