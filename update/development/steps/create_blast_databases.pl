#!/usr/bin/perl

use strict;
use Update::CreateBlastDatabases;

my $release = shift or die "Usage: $0 [WSversion]";

# Dump or mirror sequences and create blast databases
my $agent = Update::CreateBlastDatabases->new({ release => $release });
$agent->execute();

