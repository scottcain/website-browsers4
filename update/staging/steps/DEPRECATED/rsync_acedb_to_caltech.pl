#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PushAcedbToCaltech;
use Getopt::Long;

my ($release,$method,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'method=s'  => \$method);

if ($help || (!$release && !$method)) {
    die <<END;
    
Usage: $0 --release WSXXX --method [by_directory, by_package, by_release]

Rsync a newly staged version of Acedb to Caltech.

END
;
}

my $agent = WormBase::Update::Staging::PushAcedbToCaltech->new({ release => $release, method => 'by_directory' });
$agent->execute();
