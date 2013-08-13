#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::MirrorWikiPathwaysImages;
use Getopt::Long;

my ($help,$release);
GetOptions('help=s'    => \$help,
	   'release=s' => \$release);

if ($help) {
    die <<END;

Usage: $0 --release [WSXXX]

    Mirror images from WikiPathways in support of process pages.

END
;
}

my $agent = WormBase::Update::Staging::MirrorWikiPathwaysImages->new({ release => $release });
$agent->execute();
