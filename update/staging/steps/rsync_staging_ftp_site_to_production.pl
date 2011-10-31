#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::RsyncFTPSite;

my $release = shift or die "Typical Usage: $0 [WSVersion]";

my $agent = WormBase::Update::Staging::RsyncFTPSite->new({ release => $release });
$agent->execute();
