#!/usr/bin/perl

use strict;
use Update::CompileOrthologData;	

my $release = shift;
my $last_gene = shift;

my $agent = Update::CompileOrthologData->new({release => $release, last_gene=> $last_gene});
$agent->run();

