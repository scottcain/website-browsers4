#!/usr/bin/perl

use strict;
use Update::LoadClustalDB;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = Update::LoadClustalDB->new({ release => $release });
$agent->execute();

