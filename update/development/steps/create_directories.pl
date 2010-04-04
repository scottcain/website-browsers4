#!/usr/bin/perl

use strict;
use Update::CreateDirectories;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::CreateDirectories->new({ release => $release });
$agent->execute();

