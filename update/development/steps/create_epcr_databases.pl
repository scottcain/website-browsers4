#!/usr/bin/perl

use strict;
use Update::CreateEPCRDatabases;

my $release = shift or die "Usage: $0 [WSversion]";

# Dump or mirror sequences and create blast databases
my $agent = Update::CreateEPCRDatabases->new({ release => $release });
$agent->execute();

