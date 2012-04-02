#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::UnpackClustalWDatabase;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Unpack a new clustal database.

END
;
}

my $agent = WormBase::Update::Staging::UnpackClustalWDatabase->new({ release => $release });
$agent->execute();
