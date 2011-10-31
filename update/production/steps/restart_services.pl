#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::RestartServices;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 [--release] WSXXX

Restart services on production machines.

END
;
}

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::RestartServices->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::RestartServices->new();
}
$agent->execute();

