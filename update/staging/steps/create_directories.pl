#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CreateDirectories;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = WormBase::Update::Staging::CreateDirectories->new({ release => $release });
$agent->execute();

