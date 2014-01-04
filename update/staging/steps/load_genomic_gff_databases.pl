#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::LoadGenomicGFFDB;
use Getopt::Long;

my ($release,$help,$confirm_only);
GetOptions('release=s' => \$release,
	   'help'    => \$help,
	   'confirm-only' => \$confirm_only,
);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--confirm-only]

Load genomic GFF databases for all available species.

END
;
}

my $agent = WormBase::Update::Staging::LoadGenomicGFFDB->new({ release => $release,
							       confirm_only => $confirm_only});
$agent->execute();
