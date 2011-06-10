#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CompileInteractionResources;

my $release = shift or die "Usage: $0 [WSVersion]";

# Run compile
my $agent = WormBase::Update::Staging::CompileInteractionResources->new({ release => $release });
$agent->execute();
