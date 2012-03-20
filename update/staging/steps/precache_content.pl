#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PrecacheContent;
use Getopt::Long;

my ($release,$help,$class,$widget,$host);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'class=s'   => \$class,
	   'widget=s'  => \$widget,
	   'cache_query_host=s' => \$host,
    );

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--class CLASS --widget WIDGET --cache_query_host (staging|production) ]

Precache content on the classic site for a given release.

To cache only a specific widget, also provide CLASS and WIDGET.

To send queries to the production host, provide the optional --cache_query_host parameter.

Note that WHICH couchdb content will be cached to is controlled by the app itself.

END
;
}

$host ||= 'staging';

my $agent;
if ($class && $widget) {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release          => $release,
							       class            => $class,
							       widget           => $widget,
							       cache_query_host => $host,
							     });
} else {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release          => $release,
							       cache_query_host => $host,
							     });
}
$agent->execute();
