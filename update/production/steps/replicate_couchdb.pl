#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::ReplicateCouchDB;

#system('source /home/tharris/.bash_profile');

use Getopt::Long;

my ($release,$method);
GetOptions('release=s' => \$release);

unless ($release) {
    die <<END;
    
Usage: $0 --release [WSXXX]
END
;
}

my $agent;
if ($release) {
    $agent = WormBase::Update::Production::ReplicateCouchDB->new({ release => $release });
} else {
    $agent = WormBase::Update::Production::ReplicateCouchDB->new();
}
$agent->execute();
