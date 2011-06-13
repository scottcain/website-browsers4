#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushSoftware;

my $release = shift or die "Typical Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Production::PushSoftware->new({ release => $release });
$agent->execute();
