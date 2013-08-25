#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::UpdateFTPSymlinks;
use Getopt::Long;

my ($release,$help,$status);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'status=s'  => \$status);

if ($help) {
    die <<END;
    
Usage: $0 [--release WSXXX] [--status development|production]

Update symlinks on the ftp site for a new development 
or production release. If --release and --status are not
provided, the symbolic structure of the species/ directory
will be rebuilt for *all* releases.

END
;
}

my $agent = WormBase::Update::Production::UpdateFTPSymlinks->new({ release => $release,
								   status  => $status,
								 });

$agent->execute();
