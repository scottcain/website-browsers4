#!/usr/bin/perl

# Migrate SQL databases between hosts.
# Used several times throughout lifecycle.
# 1. Build:  Build instance -> development instance
# 2. Production: dev instance -> GBrowse, RDS
# 3. Backup : RDS -> backup host

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2::MoveSQLDatabasesBetweenInstances;
use Getopt::Long;

my ($help,$source_host,$source_user,$source_pass,$target_host,$target_user,$target_pass);
GetOptions(
    'help'          => \$help,
    'source_user=s' => \$source_user,
    'source_pass=s' => \$source_pass,
    'source_host=s' => \$source_host,
    'target_user=s' => \$target_user,
    'target_pass=s' => \$target_pass,
    'target_host=s' => \$target_host,
);

if ($help) {
    die <<END;
    
Usage: $0 [OPTIONS]

Move MySQL databases between instances

Options:
  --source_host,source_user,source_pass  
  --target_host,target_user,target_pass
    
   Note that -- in order to avoid data transfer charges -- the
   source_host and target_host values should be provided as CNAMEs.

END
}
    ;
    
    my $agent = WormBase::Update::EC2::MoveSQLDatabasesBetweenInstances->new(
	target_host => $target_host,
	target_user => $target_user,
	target_pass => $target_pass,
	source_host => $source_host,
	source_pass => $source_pass,
	source_user => $source_user);

$agent->execute();

1;
