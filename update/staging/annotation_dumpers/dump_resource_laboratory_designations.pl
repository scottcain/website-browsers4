#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use Getopt::Long;
use Ace;
use strict;

my ($path,$host,$port,$species);
GetOptions(
           "path=s"      => \$path,
	   "host=s"      => \$host,
	   "port=i"      => \$port,
           "species=s"   => \$species,
	  );

$path || die <<USAGE;

Usage: $0 [options]
   
   --path  Path to acedb database
   OR
   --host      hostname for acedb server
   --port      port number (for specified host)

USAGE
    ;

# Establish a connection to the database.
my $dbh = $path
    ? Ace->connect(-path => $path )
    : Ace->connect(-port => $port, -host => $host) or die $!;

my $date = `date +%Y-%m-%d`;
chomp $date;

my $emacs = $ENV{EMACS};
my $delim = $emacs ? "\n" : "\r";
my $count;

my $total = $dbh->count(Laboratory => '*');

my $i = $dbh->fetch_many(-class=>'Laboratory',-name => '*',-filled=>1) or die $dbh->error;

print "# WormBase Laboratory and Allele Designations\n";
print "# WormBase, version " . $dbh->version . "\n";
print "# Generated $date\n";
print join('/','#Lab Designation','Allele Designation','Lab Representative','Institute','Email'),"\n";
while (my $obj = $i->next) {
    print STDERR "loaded $count Laboratory$delim" if ++$count % 100 == 0;
    my $representative = eval  { $obj->Representative->Full_name };
    my $laboratory     = $obj;
    my $allele         = $obj->Allele_designation;
    my ($institute)    = $obj->Mail;
    my $email          = $obj->E_mail;
    print join("\t",$laboratory,$allele,$representative,$institute,$email),"\n";    
}

1;
