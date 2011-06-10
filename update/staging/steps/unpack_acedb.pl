#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::UnpackAcedb;

my $release = shift or die "Usage: $0 [WSVersion]";

# Unpack a freshly mirrored version of acedb.
my $agent = WormBase::Update::Staging::UnpackAcedb->new({ release => $release });
$agent->execute();
