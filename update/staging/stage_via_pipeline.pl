#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use strict;
use WormBase::Update::Factory;
use Time::HiRes qw(gettimeofday tv_interval);

my @steps = qw/
              MirrorNewRelease
              UnpackAcedb
              CreateDirectories
              CreateBlastDatabases
              CreateBlatDatabases
              LoadGenomicGFFDatabases
              CompileGeneResources
              CompileOntologyResources
              UnpackClustalWDatabase
/;

my $start = [gettimeofday];

foreach (@steps) {
    my $step = WormBase::Update::Factory->create($_,{});
    $step->execute();
}

my $end = [gettimeofday];
my $interval = tv_interval($start,$end);
my $time = sprintf("%d days, %d hours, %d minutes and %d seconds",(gmtime $interval)[7,2,1,0]);

print "Staging pipeline complete; finished in $time\n\n";
