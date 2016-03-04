#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use strict;
use WormBase::Update::Staging::CreateGBrowseConfigFiles;
use Getopt::Long;

my ($release,$help,$path);
GetOptions('release=s' => \$release,
	   'help'      => \$help,
	   'path=s'      => \$path,
);

if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX [--path PATH]

Generate GBrowse configuration files for the new release. Config files
will be placed inside the PATH directory. This should be a gbrowse configuration
directory in checked out website source.

Files will be created in PATH/releases/\$release with symlinks created to them.

Options:

     --release  REQUIRED. Release to build.
     --path     OPTIONAL. Where to place .conf files. Default:
               /usr/local/wormbae/website/tharris/conf/gbrowse

END
;
}

$path ||= "/usr/local/wormbase/website/tharris/conf/gbrowse";

my $agent = WormBase::Update::Staging::CreateGBrowseConfigFiles->new({ release => $release,
								       path    => $path,
								     });
								       
$agent->execute();
