#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::UnpackAcedb;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Unpack a freshly mirrored version of Acedb.

END
;
}

my $agent = WormBase::Update::Staging::UnpackAcedb->new({ release => $release });
$agent->execute();
