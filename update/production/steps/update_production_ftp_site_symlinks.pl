#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::UpdateProductionFTPSymlinks;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 [--release] WSXXX

Update symlinks on the production FTP site. NOTE: should be run
from the server hosting the FTP site.

END
;
}

my $agent = WormBase::Update::Production::UpdateProductionFTPSymlinks->new({ release => $release,
									   });
$agent->execute();
