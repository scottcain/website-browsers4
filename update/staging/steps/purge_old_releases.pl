#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PurgeOldReleases;
use Getopt::Long;

my ($release,$help,$target);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'target=s'  => \$target,
    );

if ($help || (!$release)) {
    die <<END;

Usage: $0 --release WSXXX --target [production|staging]    

Purge the specified old release from either the production or staging targets.

END
;
}

my $agent = WormBase::Update::Staging::PurgeOldReleases->new({release => $release, target => $target });
$agent->execute();
