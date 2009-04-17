#!/usr/bin/perl
use strict;
use File::Copy 'move', 'copy';

use constant SUP      => '/usr/local/ftp/pub/wormbase/genomes/c_briggsae/genome_feature_tables/GFF2/supplementary.gff.gz';
use constant ELEGANS  => '/usr/local/ftp/pub/wormbase/genomes/c_elegans/genome_feature_tables/GFF2/';

my $release = shift || die "Usage: ./process_briggsae_gff.pl WSXXX briggsae_gff_file.gff.gz\n";
$release =~ s/WS//i;
my $briggsae_gff = shift;
my $elegans_gff  = ELEGANS . "c_elegans.WS$release.gff.gz";

$ENV{TMP} ||= $ENV{TMPDIR}
          ||  $ENV{TEMP} 
          || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : die 'NO TEMP DIR';

#my $GFF = "/usr/local/ftp/pub/wormbase/acedb/WS$release/CHROMOSOMES/briggff${release}";

my @gff_files = $briggsae_gff;
push @gff_files, SUP;

my $temp_dir = "$ENV{TMP}/briggWS$release";
mkdir $temp_dir unless -d $temp_dir;
chdir $temp_dir or die $!;

# grab the C. elegans waba and reverse it
system "zcat $elegans_gff |grep waba |/usr/local/wormbase/bin/invert_target.pl >$ENV{TMP}/waba$$";

open ERR,">/home/todd/errors.txt";
# filter and consolidate
for (@gff_files, "$ENV{TMP}/waba$$") {
  my $sup = 1 if /supplementary/;
  $_ = "gunzip -c $_ |" if /gz$/;
  open IN, $_;
  while (my $line = <IN>) {
      if ($line =~ /Link/) {
	  print $line;
	  next;
      }

     if ($line =~ /Genomic_canonical/ && !$sup) {
	  print $line;
	  next;
      }
    next if $line =~ /waba/ && !/waba/;   # ??
    $line  =~ s/similarity/nucleotide_match/;
    $line =~ s/Sequence\s+("\S+?")/Sequence $1;Name $1/;
    $line =~ s/elegans_CHROMOSOME_//;
    print $line;
  } 

}

exit;
