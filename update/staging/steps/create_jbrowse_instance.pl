#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CreateJBrowseInstance;
use Getopt::Long;

my ($release,$config,$help,$confirm_only);
GetOptions('release=s'    => \$release,
	   'help'         => \$help,
	   'confirm-only' => \$confirm_only,
);

$config ||= "$Bin/../../../jbrowse/conf/c_elegans.jbrowse.conf";

if ($help || (!$release) ) {
    die <<END;
    
Usage: $0 --release WSXXX [--confirm-only]

Create JBrowse instance for all available species.

END
;
}

my $agent = WormBase::Update::Staging::CreateJBrowseInstance->new({ release      => $release,
							            confirm_only => $confirm_only});
$agent->execute();
