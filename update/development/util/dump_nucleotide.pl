#!/usr/bin/perl
# file: dump_nucleotide.pl
# Dumps out a nucleotide file in FASTA format containing all
# the genomic segments.  Used for BLAST search script.

# This script often returns 3328.
# Bitshifted, this is system error 13, or permission denied.
# Is this a memory issue?
#      - ace logs look fine...
#      - dumped blast filt looks fine...
# Is this an issue with ace not releasing file descriptors?

use Ace;
use strict;
# use Ace::Sequence;

# big memory structure!
#my %CACHE;

#my $return = system('ulimit -S -n 400');

my $database = shift;
my $species = shift;


# Norie: why is this hard-coded? parameterize the script instead.
my $release = "WS207"; ## $self->release
my $path = "/usr/local/wormbase/acedb/wormbase_$release"; 

$database = $path;

# connect to database
my $db;
if ($database) {
    $db = Ace->connect($database) || die "Couldn't open database";
} else {
    $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
}

# find all genomic sequences that contain DNA

my $query = 
    $species =~ /elegans/
    ? 'Genome_Sequence' : 'Briggsae_genomic';

my @sequences = $db->fetch($query => '*');
die "Couldn't get any genome sequences" unless @sequences;

# iterate through them
my $debug_counter;

foreach my $s (@sequences) {
    
    if ($debug_counter++ % 100 == 0) {
	print STDERR "$debug_counter - [$s] ... ";
	print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
    }
    
    # pull out interesting fields
    # the DNA
    next unless my $dna = $s->asDNA;
    $dna =~ s/>.*\n//;
    $dna =~ s/\n//g;
    
    # pull out identified or tentative genes
    # This isn't completely correct - some genes are not listed
    # under CDS_Child (nor were they listed under Subsequence).
    # Pre WS116
    # my @genes = $s->Subsequence;  # predicted/actual genes
    my @genes = $s->CDS_Child;  # predicted/actual genes
    my (%id,%tentative,$pruned);
    foreach (@genes) {
	# Ignore other additions to CDS_Child
	next if $_->Method eq 'Genefinder';
	$pruned++;
	my $gene = $_->fetch;
	$id{$gene->Brief_identification(1)}++ if $gene->Brief_identification;
#    $tentative{$gene->DB_remark(1)}++    if $gene->DB_remark;
	next if $gene->Brief_identification;
	
	next unless my $protein = $gene->Corresponding_protein;
	$protein = $protein->fetch;
	my $remark = $protein->Description(1) || $protein->Gene_name(1);
	$tentative{$remark}++ if $remark;
    }
    my @tentative = grep($_ && !$id{$_},keys %tentative);
    my @id        = keys %id;
    my ($gbk) = eval { $s->AC_number };
    #  my ($map) = $s->Clone->Map if $s->Clone;
    my $map;
    
    if (my ($start,$stop,$ref) = find_position($s)) {
	$map = "$ref/$start,$stop";
    }
    
    # memory problems
    #    if (my $seq = Ace::Sequence->new($s)) {
    #	$seq->absolute(1);
    #	$map = $seq->asString;
    #    }
    
    # print OUT a fasta file
    print ">$s";
    print " /gb=$gbk" if $gbk;
    print " /cds=",$pruned;
    foreach (@id) {
	tr/\n/ /;  # no newlines!
	print " /id=$_";
    }
    foreach (@tentative) {
	tr/\n/ /;  # no newlines!
	print " /tentative_id=$_";
    }
    print " /map=$map" if $map;
    print "\n";
    $dna =~ s/(.{80})/$1\n/g;
    print $dna,"\n";
#$debug_counter++;
#last if $debug_counter >1;
}

sub find_position {
  my $s = shift;
  my ($abs_offset,$length,$prev) = (1,0);
  
  for ($prev=$s, my $o = get_source($s); $o; $prev=$o,$o = get_source($o)) {
    my @subs = $o->get('Subsequence');
    my ($seq) = grep $prev eq $_,@subs;
    $length ||= $seq->right(2) - $seq->right(1) + 1;
    $abs_offset += $seq->right-1;    # offset to beginning of sequence
  }
  return ($abs_offset,$abs_offset+$length-1,$prev);
}

sub get_source {
    my $s = shift;
#    return $CACHE{$s} ||= $s->Source;
    return $s->Source;
}

