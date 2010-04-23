#!/usr/bin/perl

use strict;
use lib '/usr/local/wormbase/website-classic/extlib/lib/perl5/x86_64-linux';

use Ace;

my $ace = Ace->connect(-host=>'localhost',-port=>'2005') or die;
my $version = $ace->version;

my $command = <<END;
mkdir -p /usr/local/wormbase/databases/$version/strains
cd /usr/local/wormbase/website-classic/extlib
perl -Mlocal::lib=./
eval \$(perl -Mlocal::lib=./)
cd /home/todd/projects/wormbase/admin/update/development/
mkdir logs/$version
./steps/update_strains_db.pl $version

END
;

system($command);
