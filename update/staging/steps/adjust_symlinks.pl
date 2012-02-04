#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::AdjustSymlinks;
use Getopt::Long;

my ($release,$target,$help);
GetOptions('release=s' => \$release,
	   'target=s'  => \$target,
	   'help=s'    => \$help);

if ($help || (!$target && !$release)) {
    die <<END;
    
Usage: $0 --target [development|mirror|production|staging] --release WSXXXX

Go live with a new release of acedb on either the staging, development, 
or production nodes by adjusting the acedb and mysql symlinks.

END
;
}

my $agent = WormBase::Update::Staging::AdjustSymlinks->new({ release => $release,
							     target  => $target });
$agent->execute();
