#!/usr/bin/perl

use strict;
use local::lib '/usr/local/wormbase/website/tharris/extlib';

foreach (@ARGV) { # GFF FILES
  $_ = "gunzip -c $_ |" if /\.gz$/;
}

while (<>) {
  chomp;
#  next if /^\#/;
  my ($ref,$source,$method,$start,$stop,$score,$strand,$phase,$group) = split /\t/;

  next if $source eq 'assembly_tag'; # don't want 'em, don't need 'em
  next if $method eq 'HOMOL_GAP';    # don't want that neither  
  next if $method eq 'intron' && $source ne 'RNASeq_splice';
  next if $source eq 'intron';

  # Fix the Chromosome IDs
  $ref    =~ s/^CHROMOSOME_//;
  $group  =~ s/CHROMOSOME_//;

  # WS240 temp: fix group for the locus/Alias problem
#  $group =~ s/locus=/Alias=/;

  # WS240 temp: fix gene landmarks
#  if ($method eq 'landmark' && $source eq 'gene') {
#      $group =~ /Locus=(.*)/;
#      $group = "ID=Locus:$1;Name=$1;Alias=$1";
#  }

  print join("\t",$ref,$source,$method,$start,$stop,$score,$strand,$phase,$group) . "\n";
}
