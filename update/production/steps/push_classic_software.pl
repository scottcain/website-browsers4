#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushSoftware;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help) {
    die <<END;

Usage: $0 [--release] WSXXX

Deploy the classic version of the web app for the (optional) supplied release.

END
;
}

$release ||= 'non-release-specific-task';

my $agent = WormBase::Update::Production::PushSoftware->new({ release => $release });
$agent->execute();
