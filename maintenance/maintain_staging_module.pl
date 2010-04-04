#!/usr/bin/perl

# This simple script copies select files into the staging
# directory so that they can be synced with the production
# nodes.

# This directory is an rsync target called wormbase-live, specified
# by /etc/rsyncd.con (although production nodes are synced either by
# making an rsync request over ssh our software is pushed directly fro
# the dev machine).f

# Author: T. Harris, 16 Feb 2006

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Rsync;

umask(002);
$ENV{RSYNC_RSH} =  'ssh';

my $source_host = 'brie3.cshl.edu';

# This is the primary production node that hosts MT, main index, etc
my $production_host = 'brie6.cshl.edu';

my $user          = shift;
$user           ||= 'todd';

# 1. Copy over release notes installed into wormbase/ during the update process
chdir '/usr/local/wormbase-production/html';
rsync('/usr/local/wormbase/html/release_notes .');   # Release notes
rsync('/usr/local/wormbase/html/papers .');          # Papers

# 2. Fetch the dynamically created index file from brie6
rsync("$production_host\:/usr/local/wormbase/html/index.html .");



# 3. fetch the movable type directories (is this necessary?)
# NOT NECESSARY
#chdir '/usr/local/wormbase-production/html'; 
#rsync("$production_host\:/usr/local/wormbase/html/mt .");

# 4. Sync the RSS feeds
# NOT NECESSARY - these are served from unc
#rsync("$production_host\:/usr/local/wormbase/html/rss .");

# 5. Copy extlib from wormbase/
#chdir '/usr/local/wormbase-production';
#rsync('/usr/local/wormbase/extlib .');

# 6. Copy the databases directory into wormbase-production
# THIS WILL BE HANDLED BY A SEPAERATE PROCESS ON blast.wormbase.org only!
chdir '/usr/local/wormbase-production';
#rsync('/usr/local/wormbase/databases .');

# Copy over worm expression cartoons
chdir '/usr/local/wormbase-production/html/images/expression';
rsync('/usr/local/wormbase/html/images/expression/assembled .');

# 7. The strain seach
chdir '/usr/local/wormbase-production/html';
rsync('/usr/local/wormbase/html/strains .');

# Finally, keep the build dir in sync with the nodes
#chdir '/usr/local/wormbase-lib';
#rsync('. vab\:\/usr\/local\/wormbase-lib');
#rsync('. gene\:\/usr\/local\/wormbase-lib');
#rsync('. blast\:\/usr\/local\/wormbase-lib');
#rsync('. aceserver\:\/usr\/local\/wormbase-lib');
#rsync('. be1\:\/usr\/local\/wormbase-lib');
#rsync('. brie6\:\/usr\/local\/wormbase-lib');
