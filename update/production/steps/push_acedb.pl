#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushAcedb;
use Getopt::Long;

my ($release,$method);
GetOptions('release=s' => \$release,
	   'method=s'  => \$method);

unless ($method) {
    die <<END;
    
Usage: $0 --method [by_package|all_directories|by_directory] [--release]

To sync ALL acedb/wormbase_* directories:
 ./push_acedb.pl --method all_directories

To push out a single release using a tarball:
 ./push_acedb.pl --method by_package --release WSXXX

To push out a single release by rsyncing the directory:
 ./push_acedb.pl --method by_directory --release WSXXX

END
;
}

if (($method eq 'by_package' || $method eq 'by_directory') && !$release) {
    die <<END; 
  Usage: $0 --method by_package|by_directory --release

You *must* supply a WSRelease if pushing out acedb via tarball or as a single directory.
END
;

}


my $agent;
# Sync a single release if provided, either by package or directory method.
if ($release) {
    $agent = WormBase::Update::Production::PushAcedb->new({ release => $release,
							    method  => $method,
							  });

# Otherwise we'll sync the entire acedb/wormbase_* directories.
} else {
    $agent = WormBase::Update::Production::PushAcedb->new({method => $method});
}
$agent->execute();
