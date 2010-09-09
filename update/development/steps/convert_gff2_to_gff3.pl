#!/usr/bin/perl

use strict;
use Update::ConvertGFF2ToGFF3;

my $release = shift or die "Usage: $0 [WSVersion]";

# Create directories
my $agent = Update::ConvertGFF2ToGFF3->new({ release => $release });
$agent->execute();

