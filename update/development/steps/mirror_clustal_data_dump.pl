#!/usr/bin/perl

use strict;
use Update::MirrorClustalDataDump;

my $release = shift or die "Usage: $0 [WSVERSION]";

# Mirror ontology files
my $agent = Update::MirrorClustalDataDump->new({ release => $release });
$agent->execute();

