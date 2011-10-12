#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::RestartServices;

my $release = shift or warn "Typical Usage: $0 [WSVersion]";

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::RestartServices->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::RestartServices->new();
}
$agent->execute();

