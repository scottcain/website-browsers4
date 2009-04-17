#!/usr/bin/perl

# Tally the number of requests for each class
# from the popup menu on the main page

$|++;

foreach (@ARGV) { # access_log.*.gz
    $_ = "gunzip -c $_ |" if /\.gz$/;
}      

my %classes;
while (<>) {
    next unless ($_ =~ /http:\/\/www.wormbase.org\/ /);
    next unless ($_ =~ /basic/);
    next if ($_ =~ /google/i);
    $_ =~ /.*\/db\/searches\/basic.*class=(.*)&query=(.*)&/;
    
    my $class = $1;
    my $query = $2;
    next unless $class;
    next if $class =~ /\%/;
    push @{$classes{$class}},$query;
}

print "Sorted alphabetically...\n";
foreach (sort keys %classes) {
    my $count = @{$classes{$_}};
    print join("\t",$_,$count),"\n";
}


print "\n\nSorted by count...\n";
foreach (sort { @{$classes{$b}} <=> @{$classes{$a}} } keys %classes) {
    my $count = @{$classes{$_}};
    print join("\t",$_,$count),"\n";
}
