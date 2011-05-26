#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushSupportDatabases;

# Sync a single release if provided.
my $release = shift; # or die "Usage: $0 [WSVersion]";

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::PushSupportDatabases->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::PushSupportDatabases->new();
}
$agent->execute();
