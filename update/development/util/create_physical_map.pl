#!/usr/bin/perl

use DBI;
use FindBin '$Bin';
use File::Basename 'basename';
use Getopt::Long;
use Ace;

my $acedb = shift or die "Usage: $0 [/path/to/acedb]";

my $ENV_TMP = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : die;

my $ACE = Ace->connect($acedb) or die "Can't open ace database:",Ace->error;
my $tmp = $ENV_TMP;

my @contigs = $ACE->fetch(-class=>'Contig',-name=>'*',-fill=>1);
my $c;
foreach my $contig (@contigs) {
  $c++;

  # get the physical map coordinates for the contig and eliminate
  # those contigs where the start is greater than the end value
  my ($start,$stop) = $contig->Pmap->row;

  unless ($start > $stop) {
    # use the class tag as the method and the source for a contig
    my $source = 'contig';
    my $method = 'contig';
    
    # convert the physical map coordinates into positive numbers;
    # numbers > 100 are better visualized with GBrowse, so will
    # multiply everything by 10...
    
    # the downside is that everything now will start at 10 instead
    # of 1, is this ok?  plus, the negative numbers are going to
    # become huge!  e.g. -24 will be -240
    
    # TH: This is truly bizarre.  Is it still possible to display relative
    # starts using this method?  All the start positions
    # become flattened. I do not get it right now...
    my $offset = 1 - $start;  # same as  ((-1) * ($start)) +1
    $start     = 10 * ($start + $offset);
    $stop      = 10 * ($stop  + $offset);
    
    # these are irrelevant for the physical map
    my ($score,$strand,$phase) = qw/. . ./;
    
    # the group will be given by the class name and the id of each refseq
    my $group = "Contig $contig";
    
    # print gff 9-columns for the reference sequence (contig)
    print join "\t",($contig,$source,$method,$start,$stop,$score,$strand,$phase,$group),"\n";
    
    # get all the clones within the contig, skipping those with no PMap coords
    my @ref_clones = $contig->follow('Clone');
    foreach my $clone (@ref_clones) {
      # get the pmap coordinates of each clone relative to the refseq contig
      next unless (my ($junk,$c_start,$c_stop) = eval {$clone->get('Pmap',1)->row});
      $c_start = 10 * ($c_start + $offset);
      $c_stop  = 10 * ($c_stop  + $offset);
      
      # print STDERR join('-',$contig,$clone,$c_start,$c_stop,$start,$stop),"\n";
      
      # get the same values (as above) for each clone within the refseq contig
      my $c_type   = eval {$clone->Type};
      my $c_source = lc ($c_type) || 'clone';
      my $c_method = 'clone';
      my ($c_score,$c_strand,$cphase) = qw/. . ./;
      
      # for the group column, get the class and id of the clone, as
      # well as whether the clone has an associated DNA sequence
      my $sequence    = eval {$clone->Sequence};
      my $seq_source;
      my $c_group = "Clone $clone";
      if (eval {$clone->Sequence}) {
	$c_group .= "; Note Sequenced";
	$seq_source = 'sequenced';
      }
      #	my $buried_clone;
      #	my @status = $clone->Sequence_status;	
      #	my $finished = eval {$clone->Finished};
      $c_group .= "; Accession number " . $clone->Accession_number if (eval {$clone->Accession_number});
      
      # print gff 9-columns for each clone
      print join "\t",($contig,$c_source,$c_method,$c_start,$c_stop,$c_score,$c_strand,$c_phase,$c_group),"\n";
      
      if ($c_group =~ /Note/){
	print join "\t",($contig,$seq_source,$c_method,$c_start,$c_stop,$c_score,$c_strand,$c_phase,$c_group),"\n";
      }
    }
  }
}





