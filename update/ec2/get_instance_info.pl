#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::EC2;
use Getopt::Long;

my ($format,$help,$status);
GetOptions('format=s'     => \$format,
	   'help=s'       => \$help,
	   'status=s'     => \$status,
    );

if ($help) {
    die <<END;
    
Usage: $0

Get information on all or specific sets of instances.

Options:
  --status      optional. One of [build|development|production|qaqco]
                          If not provided defaults to listing ALL images.
  --format      short || long. Defaults to short listing.

END

}

my $agent = WormBase::Update::EC2->new({release => 'ec2'});

my $i;
if (!$status) {
    $i = $agent->get_instances();
} else {
    $i = $agent->get_instances({'tag:Status' => $status });
}

$agent->display_instance_metadata($i);
