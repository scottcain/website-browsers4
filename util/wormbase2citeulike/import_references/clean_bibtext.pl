#!/usr/bin/perl

$/ = "}\n";

my %years;

my $c;
while (<>) {  
  $c++;

  # Get rid of the leading line if one exists
  next if /^%/;
  
  # Fetch the year
  my ($year) = $_ =~ /Year="(.*)",/;
  
  my $reformatted_entry;
  my @lines = split("\n");
  foreach my $line (@lines) {
    
    my ($abstract) =  $line =~ /Abstract="(.*)"/;
    if ($abstract) {
	# $abstract =~ s/\"/\'/g;
	$line =~ s/\{//g;
	$line =~ s/\}//g;
	$line = '   Abstract={' . $abstract . '},';
    }

    my ($title) = $line =~ /Title="(.*)"/;
    if ($title) {
	$title =~ s/\{//g;
	$title =~ s/\}//g;
	$line = '   Title={' . $title . '},';
    }

    $reformatted_entry .= "$line\n";
  }

  push @{$years{$year}},$reformatted_entry;
}


foreach my $year (keys %years) {

  open OUT,">refs_by_year/c_elegans_papers.$year.bibtex.txt";
  
  # switching single qutoes to doubles in abstracts
  foreach my $entry (@{$years{$year}}) {
    print OUT $entry;
  }
  
}
