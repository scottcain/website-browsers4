#!/usr/bin/perl

use strict;
use lib '../lib';
use WormBase::Update::Development::LoadGenomicGFFDB;

my $version = shift or die "Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Development::LoadGenomicGFFDB->new(version => $version,
								  dryrun  => 1);
#my $agent = WormBase::Update::Development::LoadGenomicGFFDB->new();
$agent->execute();
