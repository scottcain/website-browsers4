#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CompileOntologyResources;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Compile flat files that power various ontology displays.

END
;
}

my $agent = WormBase::Update::Staging::CompileOntologyResources->new({ release => $release });
$agent->execute();
