#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PrecacheContent;
use Getopt::Long;

my ($release,$help,$class,$widget);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'class=s'   => \$class,
	   'widget=s'  => \$widget,);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--class CLASS --widget WIDGET]

Precache content on the classic site for a given release.

To cache only a specific widget, also provide CLASS and WIDGET.

END
;
}

my $agent;
if ($class && $widget) {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release => $release, class => $class, widget => $widget});
} else {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release => $release });
}
$agent->execute();
