#!/usr/bin/perl

use strict;
use Update::LoadGenomicGFFDB;

my $version = shift or die "Usage: $0 [WSVersion]";

my $agent = Update::LoadGenomicGFFDB->new({ version => $version });
$agent->execute();
