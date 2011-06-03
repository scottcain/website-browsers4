#!/usr/bin/perl

use strict;
use local::lib '/usr/local/wormbase/website/tharris/extlib';

foreach (@ARGV) { # GFF FILES
  $_ = "gunzip -c $_ |" if /\.gz$/;
}

while (<>) {
  chomp;
  next if /^\#/;
  my ($ref,$source,$method,$start,$stop,$score,$strand,$phase,$group) = split /\t/;

  next if $source eq 'assembly_tag'; # don't want 'em, don't need 'em
  next if $method eq 'HOMOL_GAP'; # don't want that neither  
  next if $source eq 'intron';
  next if $method eq 'intron';

  # Fix the Chromosome IDs
  $ref    =~ s/^CHROMOSOME_//;
  $group  =~ s/CHROMOSOME_//;

  print join("\n",$ref,$source,$method,$start,$stop,$score,$strand,$phase,$group);
}
