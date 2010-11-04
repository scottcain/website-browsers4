#!/usr/bin/perl

use strict;
use Update::CompileGeneResources;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = Update::CompileGeneResources->new({ release => $release });
$agent->execute();

