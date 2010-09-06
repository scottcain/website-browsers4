#!/usr/bin/perl

use strict;
use Update::MirrorWebData;

my $release = shift or die "Usage: $0 [WSVERSION]";

# Mirror ontology files
my $agent = Update::MirrorWebData->new({ release => $release });
$agent->execute();

