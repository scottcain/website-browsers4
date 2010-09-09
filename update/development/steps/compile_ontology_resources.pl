#!/usr/bin/perl

use strict;
use Update::CompileOntologyResources;

my $release = shift or die "Usage: $0 [WSVersion]";
my $agent = Update::CompileOntologyResources->new({ release => $release });
$agent->execute();

