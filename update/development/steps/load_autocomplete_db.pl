#!/usr/bin/perl

use strict;
use Update::LoadAutocompleteDB;

my $release = shift or die "Usage: $0 [WSVersion]";
my $agent = Update::LoadAutocompleteDB->new({ release => $release });
$agent->execute();

