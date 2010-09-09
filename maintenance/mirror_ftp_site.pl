#!/usr/bin/perl

# mirror_ftp_site.pl
# Author: T. Harris
# 20 Oct 2007

# This script mirrors the skeleton FTP site on the
# development server (which we use for staging during
# the build process) to the live FTP site.

# It is intended to be run under cron, eg:
# 0 2 * * * /home/todd/projects/wormbase/admin/maintenance/mirror_ftp_site.pl

use strict;
use lib '/home/todd/projects/wormbase/admin/lib';
use Rsync;

umask(022);
$ENV{RSYNC_RSH} =  'ssh';

chdir '/usr/local/ftp/pub/wormbase';
rsync('--exclude nGASP . brie4.cshl.edu\:/var/ftp/pub/wormbase');
