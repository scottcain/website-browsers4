#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::RestartServices;
use Getopt::Long;

my ($release,$help,$target);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'target=s'  => \$target);

if ($help || !$target) {
    die <<END;
    
Usage: $0 --target [development|production] [--release WSXXXX]

Restart services on [development|production] machines. If release is provided, select optional
services release-specific services will be restarted.

END
;
}

$release ||= 'non-release-specific-task';
my $agent  = WormBase::Update::Production::RestartServices->new({ release => $release, target => $target });
$agent->execute();

