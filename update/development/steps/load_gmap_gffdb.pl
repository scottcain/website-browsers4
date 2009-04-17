#!/usr/bin/perl

use strict;
use Update::LoadGeneticGFFDB;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::LoadGeneticGFFDB->new({ release => $release });
$agent->execute();

