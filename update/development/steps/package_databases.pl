#!/usr/bin/perl

use strict;
use Update::PackageDatabases;

my $release = shift or die "Usage: $0 [WSVersion]";
my $agent = Update::PackageDatabases->new({ release => $release });
$agent->execute();

