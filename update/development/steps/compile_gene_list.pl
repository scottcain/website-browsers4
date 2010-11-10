#!/usr/bin/perl

use strict;
use Update::CompileGeneList;	

my $release = shift;
my $last_gene = shift;
my $agent = Update::CompileGeneList->new({ release => $release});
$agent->run();

