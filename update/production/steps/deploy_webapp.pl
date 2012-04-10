#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::DeployWebapp;
use Getopt::Long;

my ($release,$help,$target);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'target=s'  => \$target,
    );

if ($help) {
#if ($help || (!$release)) {
    die <<END;

Usage: $0 [--release] WSXXX --target [production|staging]

Deploy web app for the current release to either the production or the staging cluster.

END
;
}

$target ||= 'staging';

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::DeployWebapp->new({ release => $release , target => $target });
} else {
    $agent = WormBase::Update::Production::DeployWebapp->new({ target => $target });
}
$agent->execute();
