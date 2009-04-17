#!/usr/bin/perl

use strict;

use constant ELEGANS  => '/usr/local/acedb/elegans';
use constant RELEASENOTES => '/usr/local/wormbase/html/release_notes';

my $real  = readlink(ELEGANS) or die "Can't read link: $!";
my ($release) = $real=~ /elegans_(WS\d+)/;
send_notification(RELEASENOTES,$release);
print "Release notification for $release has been sent!\n";

#From: "WormBase" <wormbase\@wormbase.org>

sub send_notification {
  my $dir = shift;
  my $release = shift;
  my $file = "$dir/letter.$release";
  return unless -e $file;
  warn("sending out announcement\n");
  open (MAIL,"| /usr/lib/sendmail -oi -t") or return;
  print MAIL <<END;
From: "Todd Harris" <harris\@cshl.edu>
To: wormbase-announce\@wormbase.org, wormbase\@wormbase.org
Subject: WormBase release $release now online

This is an automatic announcement that WormBase
(http://www.wormbase.org) has just been updated.  New releases occur
roughly every three weeks.

The text of the AceDB release notes, which contains highlights of the
new data is attached.

Additional information on the release, including any necessary patches or bug
fixes can be found on the WormBaseWiki:

   http://www.wormbase.org/wiki/index.php/WS$release

Downloads:
------------
You can download the full AceDB files from:

  ftp://ftp.sanger.ac.uk/pub/wormbase/current_release/
    or
  ftp://ftp.wormbase.org/pub/wormbase/acedb/current_release

Running WormBase Locally:
---------------------------
If you would like to run WormBase on your own computer, 
check out the WormBase Virtual Machine for this release:

  ftp://ftp.wormbase.org/pub/wormbase/people/tharris/vmx/$release

Documentation is available on the WormBase Wiki:

  http://www.wormbase.org/wiki/index.php/Virtual_Machines 

END
;

  foreach ($file) {
    open (F,$_) or next;
    while (<F>) { print MAIL $_; }
  }
  close F;
  close MAIL;
}
