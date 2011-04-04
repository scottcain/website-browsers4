#!/usr/bin/perl

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use WormBase::Update::Development::CreateBlastDatabases;

my $version = shift or die "Usage: $0 [WSversion]";

# Dump or mirror sequences and create blast databases
my $agent = WormBase::Update::Development::CreateBlastDatabases->new({ version => $version });
$agent->execute();

