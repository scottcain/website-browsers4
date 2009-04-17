#!/usr/bin/perl

# dump out an elegans EST file suitable for BLAST searching

use Ace;
use strict;

my $path = shift;
$|++;

# connect to database
my $db;
if ($path) {
  $db = Ace->connect($path) || die "Couldn't open database: $path";
} else {
  $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
}


#my $sock = $db->db;
#
#$sock->query('query find cDNA_Sequence');
#die "ace error: ",$sock->status,"\n"
#  if $sock->status == STATUS_ERROR;
#$sock->query('dna');

my $debug_counter;

my $query = <<END;
find cDNA_Sequence ; >DNA
END

#dna
#find NDB_Sequence
#dna
#END

#my @seqs = $db->fetch(-query=>qq{find cDNA_Sequence; dna; query find 
#NDB_Sequence; dna"});
my @seqs = $db->fetch(-query=>$query);

#while ($sock->status == STATUS_PENDING) {
#  my $h = $sock->read;
foreach (@seqs) {
  $debug_counter++;
  if ($debug_counter % 1000 == 0) {
    print STDERR "$debug_counter - [$_] ...";
    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
  }
  
#  $h =~ s/\0+\Z//; # get rid of nulls in data stream!
#  $h =~ s!^//.*!!gm;
  $_ =~ s/\0+\Z//; # get rid of nulls in data stream!
  $_ =~ s!^//.*!!gm;
	my $dna = $_->asDNA();
	print $dna if $dna;
#die;
#    next unless /^>|^[gatcn]+$/i;
}
