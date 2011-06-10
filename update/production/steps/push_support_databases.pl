#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushSupportDatabases;
use Getopt::Long;

my ($release,$method);
GetOptions('release=s' => \$release,
	   'method=s'  => \$method);

unless ($method) {
    die <<END;
    
Usage: $0 --method [by_package|all_directories|by_directory] [--release]

To sync the full support database directory:
 ./push_support_databases.pl --method all_directories

To push out a single release using a tarball:
 ./push_support_databases.pl --method by_package --release WSXXX

To push out a single release by rsyncing the directory:
 ./push_support_databases.pl --method by_directory --release WSXXX

END
;
}


if (($method eq 'by_package' || $method eq 'by_directory') && !$release) {
    die <<END; 
Usage: $0 --method by_package|by_directory --release

You *must* supply a WSRelease if pushing out support databases via tarball or as a single directory.
END
;
}



my $agent;
if ($release) {
    $agent = WormBase::Update::Production::PushSupportDatabases->new({ release => $release,
                                                                        method  => $method,
                                                                     });
} else {
    $agent = WormBase::Update::Production::PushSupportDatabases->new({method => $method });
}
$agent->execute();
