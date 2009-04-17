#!/usr/bin/perl

use strict;
use Update::MirrorAcedb;

my $release = shift or die "Usage: $0 [WSversion]";

# Mirror and unpack the new version of acedb
my $agent = Update::MirrorAcedb->new({ release => $release });
$agent->execute();

