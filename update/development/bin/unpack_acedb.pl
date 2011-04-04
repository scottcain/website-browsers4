#!/usr/bin/perl

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use WormBase::Update::Development::UnpackAcedb;

my $version = shift or die "Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Development::UnpackAcedb->new(version => $version,
							    dryrun  => 1);
$agent->execute();
