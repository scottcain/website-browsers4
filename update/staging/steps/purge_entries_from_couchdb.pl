#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::PurgeEntriesFromCouchDB;
use Getopt::Long;

my ($release,$help,$class,$widget,$host);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help,
	   'widget=s'  => \$widget,
	   'class=s'   => \$class,
	   'host=s'    => \$host);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX --widget [WIDGET]  --class [CLASS] { --host [HOST] }

Purge the specified class/widget UUIDs from couchdb.  For example, to purge all gene:sequence widgets
from the production couchdb:

--release WSXXX --widget sequences --class gene --host couchdb.wormbase.org

END
;
}

$host ||= 'localhost:5984';

my $agent = WormBase::Update::Staging::PurgeEntriesFromCouchDB->new({release      => $release,
								     class        => $class,
								     widget       => $widget,
								     couchdb_host => $host});
$agent->execute();
