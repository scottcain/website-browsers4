#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::RsyncEphemeralBuildToStableHost;
use Getopt::Long;

my ($release,$help,$target_host);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
	   'target-host=s' => \$target_host);

if ($help || !$release) {
    die <<END;
    
Usage: $0 --release WSXXX [--target-host HOSTNAME]

Mirror a new release built for the website from the ephemeral build
instance to a stable host, typically dev.wormbase.org.

If not provided, the --target-host option defaults to
   dev.wormbase.org (on ec2)

END
;
}

$target_host ||= 'dev.wormbase.org';

my $agent = WormBase::Update::Staging::RsyncEphemeralBuildToStableHost->new({release => $release,
									     target_host => $target_host});
$agent->execute();
