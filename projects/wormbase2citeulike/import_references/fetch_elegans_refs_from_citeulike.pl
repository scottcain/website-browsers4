#!/usr/bin/perl

$/ = "}\n\n";

my %years;

my ($c,$total);
while (<>) {  
  $total++;
  next unless $_ =~ /\{caenorhabditis\\_elegans,\scelegans,\selegans\},/;
  print $_;
  $c++;
}
print STDERR "seen $total; saved: $c\n";

