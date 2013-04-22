#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use lib "/usr/local/wormbase/extlib/lib/perl5";
use lib "/usr/local/wormbase/extlib/lib/perl5/x86_64-linux-gnu-thread-multi";
use strict;
use WormBase::Update::Staging::CheckForNewRelease;
use Getopt::Long;

my ($help);
GetOptions(
	   'help=s'    => \$help);

if ($help) {
    die <<END;
    
Usage: $0

Check for the presence of the NEXT WormBase release at the Hinxton site.

END
;
}

my $agent = WormBase::Update::Staging::CheckForNewRelease->new();
$agent->execute();
