#!/usr/bin/perl

use strict;
use Update::UnpackGFFMySQLDBs;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = Update::UnpackGFFMySQLDBs->new({ release => $release });
$agent->execute();
