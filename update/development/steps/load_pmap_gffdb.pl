#!/usr/bin/perl

use strict;
use Update::LoadPMAPGFFDB;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::LoadPMAPGFFDB->new({ release => $release });
$agent->execute();

