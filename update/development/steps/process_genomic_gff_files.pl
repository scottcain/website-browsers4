#!/usr/bin/perl

use strict;
use Update::ProcessGenomicGFFFiles;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = Update::ProcessGenomicGFFFiles->new({ release => $release });
$agent->execute();

