#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::MirrorNewRelease;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s' => \$release,
	   'help=s'    => \$help);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Mirror a specific release (or by omitting --release, the entire Hinxton FTP site.)

END
;
}

my $agent;

# Optionally mirror a specific release.
if ($release) {

    $agent = WormBase::Update::Staging::MirrorNewRelease->new({release => $release});

} else { 

    # Or autodiscover the last release and mirror the next one (preferred)    
    $agent = WormBase::Update::Staging::MirrorNewRelease->new();
}

$agent->execute();
