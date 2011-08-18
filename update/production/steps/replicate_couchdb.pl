#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::ReplicateCouchDB;

#system('source /home/tharris/.bash_profile');

my $release = shift or warn "Suggested Usage: $0 [WSVersion] (otherwise all dbs will by replicated)";

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::ReplicateCouchDB->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::ReplicateCouchDB->new();
}
$agent->execute();
