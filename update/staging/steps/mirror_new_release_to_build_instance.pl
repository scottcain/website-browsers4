#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::MirrorNewReleaseToBuildInstance;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || !$release) {
    die <<END;
    
Usage: $0 --release WSXXX

Mirror a new release from the FTP site to ephemeral storage on the 
build instance.

END
;
}

my $agent = WormBase::Update::Staging::MirrorNewReleaseToBuildInstance->new({release => $release});
$agent->execute();
