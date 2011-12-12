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

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --target [development|production] [--release] WSXXXX

Restart services on [development|production] machines.

END
;
}

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::RestartServices->new({ release => $release, target => $target });
} else {
    $agent = WormBase::Update::Production::RestartServices->new( { target => $target });
}
$agent->execute();

