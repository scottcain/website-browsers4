#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::GoLive;

my $release = shift or warn "Typical Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Production::GoLive->new({ release => $release });
$agent->execute();
