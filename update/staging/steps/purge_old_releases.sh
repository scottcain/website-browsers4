#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PurgeOldReleases;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Purge the specified old release from both production nodes AND the staging host.

END
;
}

my $agent = WormBase::Update::Staging::PurgeOldReleases->new({release => $release});
$agent->execute();
