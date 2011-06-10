#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CompileGeneResources;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create Blast Databases
my $agent = WormBase::Update::Staging::CompileGeneResources->new({ release => $release });
$agent->execute();
