#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CheckCachedContent;
use Getopt::Long;

my ($release,$help,$couchdb_host);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
	   'couchdb_host=s' => \$couchdb_host,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--couchdb_host (HOST) ]
    
    Do some sanity testing of a cache.

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

     Check the production cache:
         --couchdb production

     Check the qaqc cache:
         --couchdb qaqc

END
;
}


my $agent = WormBase::Update::Staging::CheckCachedContent->new({ release          => $release,
								 couchdb_host     => $couchdb_host,
							       });
$agent->execute();
