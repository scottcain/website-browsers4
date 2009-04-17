#!/usr/bin/perl

use strict;
use Update::DumpFeatures;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::DumpFeatures->new({ release => $release });
$agent->execute();


