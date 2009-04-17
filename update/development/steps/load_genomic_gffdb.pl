#!/usr/bin/perl

use strict;
use Update::LoadGenomicGFFDB;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::LoadGenomicGFFDB->new({ release => $release });
$agent->execute();

