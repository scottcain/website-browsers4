#!/usr/bin/perl

use strict;
use Update::LoadGFFPatches;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::LoadGFFPatches->new({ release => $release });
$agent->execute();

