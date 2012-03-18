#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::DeployWebapp;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help) {
#if ($help || (!$release)) {
    die <<END;

Usage: $0 [--release] WSXXX

Deploy web app for the current release.

END
;
}

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::DeployWebapp->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::DeployWebapp->new();
}
$agent->execute();
