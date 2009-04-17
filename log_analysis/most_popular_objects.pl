#!/usr/bin/perl

# Calculate the most popular objects for a given class

use strict;
use Getopt::Long;
use CGI qw/:standard *table *TR *div *td/;
use Ace;

my (@logs,$not_accessed,$output,$format,$class,$url);
GetOptions('logs=s'         => \@logs,
	   'not_accessed=s' => \$not_accessed,
	   'output=s'       => \$output,
	   'format=s'       => \$format,
	   'class=s'        => \$class,
	   'url=s'          => \$url);

unless (@logs) {
    print STDERR <<END;
  Usage: most_popular_objects.pl [options]
      
    Options:
      -logs    list of access_logs to include, seperated by spaces
      -not_accessed  print a list of genes not accessed
      -output  full path to the output directory
      -url     URL snipper (/db/gene/variation)
      -class   The class of objects to tally
      -format  one of HTML,TAB,TEXT
END
      die;
}

my (%objects_hit,%all_stats);

@ARGV = @logs;
foreach (@ARGV) {
    $_ = "gunzip -c $_ |" if /\.gz$/;
}


while (<>) {
    chomp;
    if (my ($request) = m|\"GET\shttp\://.*$url\?name=(.+?)[;&\s].*\s?HTTP.*|) {

	$request =~ s/%20A/ /g;
	$request =~ s/%0A//g;
	$request =~ s/%5B/\[/g;
	$request =~ s/%5D/\]/g;	

	$objects_hit{$request}->{total_accessions}++;  # Total of times the object was accessed
	
	# track all the different identifiers that were used to access this object
	$objects_hit{$request}->{accessors}->{$request}++;
    }
}

$all_stats{unique_accessions} = scalar keys %objects_hit;

my $suffix = ($format eq 'TAB' || $format eq 'TEXT') ? 'txt' : 'html';

# Print out genes hit in descending order of total accessions
open OUT,">$output/$class-most_popular.$suffix";

if ($format eq 'TEXT') {
    printf OUT "%-15s %-15s\n",
    qw/Object Total_accesses/;
} elsif ($format eq 'TAB') {
    print OUT join("\t",'Object','Total_accesses'),"\n";
} else {
    start_page("Most Popular $class Objects");
    print OUT
	start_div({-class=>'container'}),
	div({-class=>'category'},'Most popular $class objects, in order of number of accessions'),
	start_table({-class=>'incontainer',-cellpadding=>10}),
	TR({-class=>'pageentry'},
	   td('Object'),
	   td('Total accesses'),
	   );
}

foreach my $object (sort {$objects_hit{$b}->{total_accessions} <=> $objects_hit{$a}->{total_accessions} }
		  keys %objects_hit) {
    
    my $total_accesses = $objects_hit{$object}->{total_accessions};
    
#    # Examine all the different IDs that were used to access this gene
#    my %seen;
#    my @accessed_by;
#    foreach my $accessed_by (grep {!$seen{$_}++} keys %{$objects_hit{$object}->{accessors}}) {
#	my $accesses = $objects_hit{$object}->{accessors}->{$accessed_by};
#	push (@accessed_by,"$accessed_by ($accesses)");
#    }
    
    if ($format eq 'TEXT') {
	printf OUT "%-15s %-15s\n",
	$object,
	$total_accesses;
    } elsif ($format eq 'TAB') {
	print OUT join("\t",
		       $object,
		       $total_accesses
		       ),"\n";
    } else {
	print TR({-class=>'pageentry'},
		 td($object),
		 td($total_accesses)
		 );
    }
}

if ($format eq 'HTML') {
  print OUT end_table,end_div,end_html;
}


print OUT "\n\n-----------------------\n";
print OUT "Total unique $class objects accessed        : " . $all_stats{unique_accessions} . "\n";

close OUT;







sub mean {
  my ($num,$denom) = @_;
  my $mean = (($num || 0) / $denom) * 100;
  return (' ' . sprintf("%2.2f%",$mean));
}




sub start_page {
  my $title = shift;
  print header;
  print start_html(-title=>$title);
}
