#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::RestartServices;

my $release = shift or die "Typical Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Production::RestartServices->new({ release => $release });
$agent->execute();
