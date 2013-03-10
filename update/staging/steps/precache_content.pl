#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PrecacheContent;
use Getopt::Long;

my ($release,$help,$class,$widget,$queries_to,$already_cached,$couchdb_host);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
	   'class=s'       => \$class,
	   'widget=s'      => \$widget,
	   'queries_to=s'  => \$queries_to,
	   'already_cached_via=s' => \$already_cached,
	   'couchdb_host=s' => \$couchdb_host,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--class CLASS --widget WIDGET --queries_to (URI) --already_cached_via (logs|couchdb) --couchdb_host (HOST) ]
    
     Precache content for the supplied release.

     To cache only a specific widget, also provide CLASS and WIDGET.

     --queries_to
     Fully qualified URI of where to send queries.
     Default: http://staging.wormbase.org/

     --already_cached_via
     Specified how we will check if a given URL has already been cached. 
     When caching against a (non-localhost) remote server
     it is usually faster to use the "log" option. This will parse the cache log.
     Otherwise, the couchdb_host will be checked.
     Default: couchdb

     --couchdb_host
     The location of the couchdb, one of staging, localhost, or production. You should
     be able to read/write to this URL. Port 5984 will be appended. This controls:
          1. creating a new couch
          2. bulk operations against the couchdb
          3. checking if a url has been cached (if --already_cached_via set to couch)
     Can either be a location or symbolic name of staging/production.
     The actual couchdb where content is cached is controlled by wormbase_*.conf and 
     the app itself. Note: the locations of staging and production couches are kept in
     lib/WormBase/Role/Config.pm.
     Default: localhost:5984

     Recommended settings:
     (Typical) Run the precache script on a development host (qaqc.wormbase.org):
          * with queries to: qaqc.wormbase.org
	  * to a couchdb on: localhost
	  * verifying precache using: couchdb
          --queries_to http://qaqc.wormbase.org/ --already_cached_via couchdb --couchdb localhost:5984

     Run the precache script on one development host (say, qaqc.wormbase.org)
     with queries to another:
          * with queries to: staging.wormbase.org
	  * to a couchdb on: staging.wormbase.org
	  * verifying precache using: couchdb
          --queries_to http://staging.wormbase.org/ --already_cached_via couchdb --couchdb staging

     Run the precache script on a production host (couchdb.wormbase.org) with queries
     to antother:
          * with queries to: www.wormbase.org
	  * to a couchdb on: production
	  * verifying precache using: couchdb
         --queries_to http://www.wormbase.org/ --already_cached_via couchdb --couchdb production

     Run the precache script on a development host (qaqc.wormbase.org) with queries
     to production:
          * with queries to: www.wormbase.org
	  * to a couchdb on: production
	  * verifying precache using: logs
         --queries_to http://www.wormbase.org/ --already_cached_via logs --couchdb production

END
;
}

$queries_to ||= 'staging';

my $agent;
if ($class && $widget) {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release          => $release,
							       class            => $class,
							       widget           => $widget,
							       queries_to       => $queries_to,
							       couchdb_host     => $couchdb_host,
							       already_cached_via => $already_cached,
							     });
} elsif ($class) {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release          => $release,
							       class            => $class,
							       queries_to       => $queries_to,
							       couchdb_host     => $couchdb_host,
							       already_cached_via => $already_cached,
							     });

} else {
    $agent = WormBase::Update::Staging::PrecacheContent->new({ release          => $release,
							       queries_to       => $queries_to,
							       couchdb_host     => $couchdb_host,
							       already_cached_via => $already_cached,
							     });
}
$agent->execute();
