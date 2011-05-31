#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Production::PushMysqlDatabases;
use Getopt::Long;

my ($release,$method);
GetOptions('release=s' => \$release,
	   'method=s'  => \$method);

unless ($method && $release) {
    die <<END;
    
Usage: $0 --method [by_package|by_directory]

To sync ALL data/*WSXXX directories as a tarball:
 ./push_acedb.pl --method by_package

To push out a single release by rsyncing the directory:
 ./push_acedb.pl --method by_directory --release WSXXX

END
;
}


my $agent = WormBase::Update::Production::PushMysqlDatabases->new({ release => $release,
								    method  => $method,
								  });
$agent->execute();
