#!/usr/bin/perl

use strict;
use Update::MirrorAnnotations;

my $release = shift or die "Usage: $0 [WSVERSION]";

# Mirror ontology files
my $agent = Update::MirrorAnnotations->new({ release => $release });
$agent->execute();

