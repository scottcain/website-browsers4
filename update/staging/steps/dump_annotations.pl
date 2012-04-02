#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::DumpAnnotations;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Dump files of commonly requested annotations.

END
;
}

my $agent = WormBase::Update::Staging::DumpAnnotations->new({ release => $release });
$agent->execute();
