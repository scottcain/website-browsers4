#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::DumpMySQLDatabases;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || !$release) {
    die <<END;
    
Usage: $0 --release WSXXX

Dump MySQL databases to databases/RELEASE/sql_dumps

END
;
}

my $agent = WormBase::Update::Staging::DumpMySQLDatabases->new({release => $release});
$agent->execute();
