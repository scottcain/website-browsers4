#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::MirrorParaSite;
use Getopt::Long;

my ($release,$help);
GetOptions(
	   'help=s'    => \$help);

if ($help) {
    die <<END;
    
Usage: $0 --release WSXXX

Mirror the ParaSite FTP site.

END
;
}

my $agent = WormBase::Update::Staging::MirrorParaSite->new();

$agent->execute();
