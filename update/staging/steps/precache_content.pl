#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PrecacheContent;

my $release = shift or die "Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Staging::PrecacheContent->new({ release => $release });
$agent->execute();
