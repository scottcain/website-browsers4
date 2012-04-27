#!/usr/bin/perl

while (<>) {
    my ($class,$gene,$widget) = split("\t",$_);
#    next if $widget eq 'homology';
    next if $widget eq 'location';
#    next if $widget eq 'sequences';
    print $_;
}
