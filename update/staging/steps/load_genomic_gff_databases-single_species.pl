#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::LoadGenomicGFFDB;
use Getopt::Long;

my ($release,$desired_species,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'desired_species=s' => \$desired_species,
    );

if ($help || (!$release && !$desired_species)) {
    die <<END;
    
Usage: $0 --release WSXXX --desired_species [c_elegans, c_briggsae, etc]

Load the genomic GFF database for a given species.

END
;
}


my $agent = WormBase::Update::Staging::LoadGenomicGFFDB->new({ release => $release, desired_species => $desired_species });
$agent->execute();
