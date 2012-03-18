#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::RsyncFTPSite;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Rsync staging FTP site to the production FTP site.

END
;
}

my $agent = WormBase::Update::Staging::RsyncFTPSite->new({ release => $release });
$agent->execute();
