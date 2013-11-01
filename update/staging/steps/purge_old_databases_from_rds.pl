#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PurgeOldDatabasesFromRDS;
use Getopt::Long;

my ($release,$help,$target);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
    );

if ($help || (!$release)) {
    die <<END;

Usage: $0 --release WSXXX 

Purge old databases for a given release from RDS.

END
;
}

my $agent = WormBase::Update::Staging::PurgeOldDatabasesFromRDS->new({release => $release });
$agent->execute();
