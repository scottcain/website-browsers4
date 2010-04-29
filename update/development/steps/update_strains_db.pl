#!/usr/local/bin/perl

use strict;
use Update::UpdateStrainsDB;

my $release = shift or die "Usage: $0 [WSVersion]";
my $agent = Update::UpdateStrainsDB->new({ release => $release });
$agent->execute();

