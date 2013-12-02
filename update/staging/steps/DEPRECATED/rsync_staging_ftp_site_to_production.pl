#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::RsyncFTPSite;
use Getopt::Long;

my ($help);
GetOptions('help=s'    => \$help);

if ($help) {
    die <<END;

Usage: $0

Rsync staging FTP site to the production FTP site.

END
;
}

my $agent = WormBase::Update::Staging::RsyncFTPSite->new({ release => 'release_independent_steps' });
$agent->execute();
