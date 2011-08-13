#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::ReplicateCouchDB;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Production::ReplicateCouchDB->new({ release => $release });
$agent->execute();
