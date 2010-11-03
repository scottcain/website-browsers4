#!/usr/bin/perl

use strict;
use Update::CompileInteractionData;

my $release = shift or die "Usage: $0 [WSversion]";

# Mirror and unpack the new version of acedb
my $agent = Update::CompileInteractionData->new({ release => $release });
$agent->execute();

