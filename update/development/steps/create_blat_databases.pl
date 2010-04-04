#!/usr/bin/perl

use strict;
use Update::CreateBlatDatabases;

my $release = shift or die "Usage: $0 [WSversion]";

# Dump or mirror sequences and create blast databases
my $agent = Update::CreateBlatDatabases->new({ release => $release });
$agent->execute();

