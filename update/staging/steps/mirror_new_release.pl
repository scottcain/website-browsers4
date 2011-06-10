#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::MirrorNewRelease;

my $release = shift; #  or die "Usage: $0 [WSXXX]";
my $agent;

# Optionally mirror a specific release.
if ($release) {

    $agent = WormBase::Update::Staging::MirrorNewRelease->new({release => $release});

} else { 

    # Or autodiscover the last release and mirror the next one (preferred)    
    $agent = WormBase::Update::Staging::MirrorNewRelease->new();
}

$agent->execute();
