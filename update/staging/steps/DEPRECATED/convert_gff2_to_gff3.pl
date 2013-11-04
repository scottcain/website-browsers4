#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::ConvertGFF2ToGFF3;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Convert GFF2 to GFF3 for all available species.

END
;
}

my $agent = WormBase::Update::Staging::ConvertGFF2ToGFF3->new({ release => $release });
$agent->execute();
