#!/usr/bin/perl

use strict;
use Update::CompileOrthologyResources;

my $release = shift or die "Usage: $0 [WSVersion]";
my $agent = Update::CompileOrthologyResources->new({ release => $release });
$agent->execute();

