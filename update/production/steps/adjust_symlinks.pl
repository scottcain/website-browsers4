#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::AdjustSymlinks;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXXX

Go live with a new release of acedb on either the staging, development, 
or production nodes by adjusting the acedb and mysql symlinks.

END
;
}

my $agent = WormBase::Update::Staging::AdjustSymlinks->new({ release => $release});
$agent->execute();
