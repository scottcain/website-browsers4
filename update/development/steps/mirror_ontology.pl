#!/usr/bin/perl

use strict;
use Update::MirrorOntology;

my $release = shift or die "Usage: $0 [WSVERSION]";

# Mirror ontology files
my $agent = Update::MirrorOntology->new({ release => $release });
$agent->execute();

