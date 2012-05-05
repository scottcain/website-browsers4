#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::BuildXapianDB;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Build the Xapian-powered search database.

END
;
}


my $agent = WormBase::Update::Staging::BuildXapianDB->new({ release => $release });
$agent->execute();
