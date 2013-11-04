#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::RsyncEphemeralBuildToStableHost;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || !$release) {
    die <<END;
    
Usage: $0 --release WSXXX

Mirror a new release built for the website from the ephemeral build
instance to a stable host, typically dev.wormbase.org.

END
;
}

my $agent = WormBase::Update::Staging::RsyncEphemeralBuildToStableHost>new({release => $release});
$agent->execute();
