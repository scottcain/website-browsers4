#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CreateWidgetAcedmp;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create Widgets.ace file to power search for wormbase_user database content (editable widgets/comments)

END
;
}


my $agent = WormBase::Update::Staging::CreateWidgetAcedmp->new({ release => $release });
$agent->execute();
