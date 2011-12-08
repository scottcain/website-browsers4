#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PushAcedbToCaltech;

my $release = shift;
my $method  = shift;

unless ($release) {
    die "Typical Usage: $0 [WSVersion]";    
}

my $agent = WormBase::Update::Staging::PushAcedbToCaltech->new({ release => $release, method => 'by_directory' });
$agent->execute();
