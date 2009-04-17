#!/usr/bin/perl

# Create a software release of the WormBase site.
# This is intended to be run on the development server.

use strict;
my $version = shift;

my %month2num = ( Jan => '01',
		  Feb => '02',
		  Mar => '03',
		  Apr => '04',
		  May => '05',
		  Jun => '06',
		  Jul => '07',
		  Aug => '08',
		  Sep => '09',
		  Oct => '10',
		  Nov => '11',
		  Dec => '12');

$version || die "Usage: create_software_release.pl WSXXX [optional: boolean to add cvs tag]";

my $date = `date +%Y-%m-%d`;
chomp $date;

chdir("/usr/local/ftp/pub/wormbase/software/archive");
system("cvs export -r $version -d wormbase-$version-$date wormbase-site");
system("tar czf wormbase-$version-$date.tgz wormbase-$version-$date");
system("rm -rf wormbase-$version-$date");
chdir('/usr/local/ftp/pub/wormbase/software');
unlink("current.tgz");
system("ln -s archive/wormbase-$version-$date.tgz current.tgz");
