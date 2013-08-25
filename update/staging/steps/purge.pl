#!/usr/bin/perl

my $class = shift;
chomp $class;

my $widget = shift;
chomp $widget;

system(" mv /usr/local/wormbase/databases/WS232/cache/logs/$class.log /usr/local/wormbase/databases/WS232/cache/logs/$class.original.log");
open IN,"/usr/local/wormbase/databases/WS232/cache/logs/$class.original.log" or die "$!";
open OUT,">>/usr/local/wormbase/databases/WS232/cache/logs/$class.log";
    
while (<IN>) {
    chomp;
    my ($class,$obj,$name,$url,$status,$cache_stop) = split("\t");
    next if (($name eq $widget) && defined $objects->{$obj});
    print OUT join("\t",$class,$obj,$name,$url,$status,$cache_stop),"\n";
}
close IN;
close OUT;
system("rm /usr/local/wormbase/databases/WS232/cache/logs/$class.original.log");
