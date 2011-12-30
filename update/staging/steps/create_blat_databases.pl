#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CreateBlatDatabases;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create BLAT databases for all available species.

END
;
}

my $agent = WormBase::Update::Staging::CreateBlatDatabases->new({ release => $release });
$agent->execute();
