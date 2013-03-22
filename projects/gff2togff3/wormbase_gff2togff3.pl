#!/usr/bin/perl

#
# Convert (WormBase) GFF2 to GFF3
# Original version: P. Canaran
# Expanded and genericized: T. Harris, 4/2009 (info@toddharris.net)

#use warnings;
use strict;

use GFF3Converter;    # Utility subroutines
use Text::ParseWords qw(quotewords);
use Getopt::Long;
use Data::Dumper;
use Carp;

use constant PURGE => 1;

# - Superceded -
# This URL corresponds to sofa.ontology file of SOFA Release 2 (the release 2
# file is labeled as revision 1.32, but is identical to 1.28, revision 1.32
# is inaccessible through the public CVS)
# our $DEFAULT_SOFA = qq[GET 'http://song.cvs.sourceforge.net/*checkout*/song/ontology/sofa.ontology?revision=1.28' |];

# Default SOFA file
# SOFA Release 2.1 is available. Also switching to sofa.obo (instead
# of sofa.ontology)
our $DEFAULT_SOFA =
  qq[GET 'http://song.cvs.sourceforge.net/*checkout*/song/ontology/sofa.obo?revision=1.54' |];

my $usage = qq($0 [-sofa <SOFA file>] [-sort] -species <elegans|briggsae> -gff <gff file>);

my ($sofa,$sort,$species,$gff,$output);
GetOptions(
	   'gff=s'     => \$gff,
	   'output=s'  => \$output,
	   'sofa=s'    => \$sofa,
	   'species=s' => \$species,
	   'sort'      => \$sort,
	   )
    or die $usage;

die $usage unless $gff;
die "GFF file ($gff) cannot have gff3 extension!"
    if $gff =~ /\.gff3$/i;

$sofa ||= $DEFAULT_SOFA;
our $DEFAULT_SOFA_TERMS = parse_sofa($sofa);

#die $usage if (!$species || $species !~ /(c_elegans|c_briggsae)$/);


my $converter = GFF3Converter->new($output);


# Containers
our %GENE;           # Aggregated gene features
our @CDS;            # CDS parts

# Lookup tables (all practically 1-to-1)
our %TRANSCRIPT2GENE; # many-to-1
our %TRANSCRIPT2CDS;  # many-to-1
our %GENE2TRANSCRIPT; # 1-to-many
our %CDS2TRANSCRIPT;  # 1-to-many
our %CDS2PROTEIN;     # 1-to-1

our %PSEUDOGENES_BY_EXON; # Index
our %PSEUDOGENES_BY_BLOCK; # Index

our %CDS_MD5_LIST;

# Sofa terms
my %SOFA_TERMS = (
		  Clone_left_end                        => 'clone_insert_start',
		  Clone_right_end                       => 'clone_insert_end',
		  coding_exon                           => 'exon',
		  complex_change_in_nucleotide_sequence => 'complex_substitution',
		  miRNA_primary_transcript              => 'miRNA',
		  misc_feature                          => 'region',
		  rRNA_primary_transcript               => 'rRNA',
		  scRNA_primary_transcript              => 'scRNA',
		  SL1_acceptor_site                     => 'trans_splice_acceptor_site',
		  SL2_acceptor_site                     => 'trans_splice_acceptor_site',
		  snoRNA_primary_transcript             => 'snoRNA',
		  snRNA_primary_transcript              => 'snRNA',
		  tRNA_primary_transcript               => 'tRNA',
		  Pseudogene                            => 'pseudogene',
		  Sequence                              => 'region',
		  rflp_polymorphism                     => 'RFLP_fragment',
		 );

# Feature list
our %REGULAR_FEATURES = map { $_ => 1 } qw(
					  binding_site:miRanda
					 binding_site:PicTar
				       cDNA_match:BLAT_mRNA_BEST
				     cDNA_match:BLAT_mRNA_OTHER
				   Clone_left_end:misc_feature
				 Clone_right_end:misc_feature
			      complex_change_in_nucleotide_sequence:Allele
			    complex_substitution:misc_feature
			  deletion:Allele
			EST_match:BLAT_EST_BEST
		      EST_match:BLAT_EST_OTHER
		    experimental_result_region:cDNA_for_RNAi
		  experimental_result_region:Expr_profile
		expressed_sequence_match:BLAT_OST_BEST
	      expressed_sequence_match:BLAT_OST_OTHER
	    gene:landmark
	  insertion:Allele
	inverted_repeat:inverted
      misc_feature:binding_site
    nucleotide_match:BLAT_BAC_END
  nucleotide_match:BLAT_briggsae_est
 nucleotide_match:BLAT_elegans_est
 nucleotide_match:BLAT_elegans_mrna
 nucleotide_match:BLAT_elegans_ost
 nucleotide_match:BLAT_EST_BEST
 nucleotide_match:BLAT_EST_OTHER
 nucleotide_match:BLAT_mRNA_BEST
 nucleotide_match:BLAT_mRNA_OTHER
 nucleotide_match:BLAT_ncRNA_BEST
 nucleotide_match:BLAT_ncRNA_OTHER
 nucleotide_match:BLAT_NEMATODE
  nucleotide_match:BLAT_OST_BEST
  nucleotide_match:BLAT_OST_OTHER
  nucleotide_match:BLAT_TC1_BEST
  nucleotide_match:BLAT_TC1_OTHER
  nucleotide_match:BLAT_WASHU
  nucleotide_match:TEC_RED
  nucleotide_match:waba_coding
  nucleotide_match:waba_strong
  nucleotide_match:waba_weak
  nucleotide_match:wublastx
  oligo:misc_feature
  operon:operon
  PCR_product:GenePair_STS
  PCR_product:Orfeome
  PCR_product:Promoterome
  polyA_signal_sequence:polyA_signal_sequence
  polyA_site:polyA_site
  polymorphism:predicted
  protein_match:wublastx
  reagent:Expr_pattern
  reagent:Oligo_set
  region:Genbank
  region:Genomic_canonical
  region:Link
  region:Vancouver_fosmid
  repeat_region:RepeatMasker
  rflp_polymorphism:predicted       
  RNAi_reagent:RNAi_primary
  RNAi_reagent:RNAi_secondary
  SAGE_tag:SAGE_tag
  SAGE_tag:SAGE_tag_genomic_unique
  SAGE_tag:SAGE_tag_most_three_prime
  SAGE_tag:SAGE_tag_unambiguously_mapped
  Sequence:contig  
  Sequence:Genomic_canonical       
  sequence_variant:Allele
  sequence_variant:misc_feature
  SL1_acceptor_site:SL1
  SL2_acceptor_site:SL2
  SNP:Allele
  substitution:Allele
  tandem_repeat:tandem
  translated_nucleotide_match:BLAT_NEMATODE
  translated_nucleotide_match:BLAT_NEMBASE
  translated_nucleotide_match:BLAT_WASHU
  translated_nucleotide_match:mass_spec_genome
  transposable_element_insertion_site:Allele
  transposable_element_insertion_site:Mos_insertion_allele
  transposable_element:Transposon       
  transposable_element:Transposon_CDS
);

# Feature list - things that we do not know how to map
our %DISCARD_FEATURES = map { $_ => 1 } qw(
  coding_exon:curated
  coding_exon:Transposon_CDS
  exon:Coding_transcript
  exon:curated
  exon:Genefinder
  exon:GeneMarkHMM
  exon:mSplicer_orf
  exon:mSplicer_transcript
  exon:Transposon
  exon:Transposon_CDS
  exon:twinscan
  gene:curated
  gene:gene
  intron:.
  intron:curated
  intron:Transposon
  intron:Transposon_CDS
  intron:Genefinder
  intron:history
  intron:twinscan
  intron:Pseudogene
  processed_transcript:gene
  Sequence:.
  Transcript:history
);





# Order of reserved tags
our %TAG_ORDER = (
    'ID'            => 10,
    'Parent'        => 9,
    'Alias'         => 8,
    'Name'          => 7,
    'Target'        => 6,
    'Gap'           => 5,
    'Derives_from'  => 4,
    'Note'          => 3,
    'Dbxref'        => 2,
    'Ontology_term' => 1,
);

# List of reference sequences (seq_ids) and their last position 
# (to be used by sequence-region directive)
our %SEQUENCE_REGION_ENDS;

# Chromosome names - ACK. Not portable.
our %CHROMOSOME_NAMES = ( I             => 1,
                          II            => 2, 
                          III           => 3, 
                          IV            => 4, 
                          V             => 5, 
                          X             => 6, 
                          MtDNA         => 7,
                          chrI          => 8,
                          chrI_random   => 9,
                          chrII         => 10,
                          chrII_random  => 11,
                          chrIII        => 12,
                          chrIII_random => 13,
                          chrIV         => 14,
                          chrIV_random  => 15,
                          chrV          => 16,
                          chrV_random   => 17,
                          chrX          => 18,
                          chrUn         => 19,
                          );






# Read file - should accept gzip
#$gff = "gunzip -c $gff |" if $gff =~ /\.gz$/;
#foreach (@ARGV) { $_ = "gunzip -c $_|" if /\.gz/ }

# Goofy.
my $file = $gff;
open(FILE, "<$file") or warn("Cannot read file ($file): $!");

while (my $line = <FILE>) {
  chomp $line;
  next unless $converter->check_for_duplicate_lines($line);
  
  # Discard comments and directives
  if ($line =~ /^#/ || !$line) {
    print $converter->logs('discard') "$line\n";
    next;
  }
  
  # Parse lines (and attributes)
  my $feature = $converter->parse_line($line);

  # Tried to parse the line and got nothing? It must be broken. Ignore it.
  if (!defined $feature) {
    print $converter->logs('not_parsed') "$line\n";
    next;
  }
  
  # Ignore entries that have no reference sequence.
  if (!$feature->{ref}) {
    print $converter->logs('not_parsed') "no-ref: $line\n";
    next;
  }
  
  $converter->adjust_start_and_stop($feature);
  
  # Pull features out of the feature hash for easier access
  my $ref        = $feature->{ref};
  my $source     = $feature->{source};
  my $method     = $feature->{method};
  my $start      = $feature->{start};
  my $end        = $feature->{end};
  my $score      = $feature->{score};
  my $strand     = $feature->{strand};
  my $phase      = $feature->{phase};
  my $attributes = $feature->{attributes};
  
  # Create a composite lookup key.
  my $key = "$method:$source";
  
  # Can we turn this feature into a SOFA compliant term?
  if (my $new_key = $converter->features_to_convert($key)) {
    my ($new_method, $new_source) = split(':', $new_key);
    
    # Stash the new type and source for the feature
    $feature->{method} = $new_type;
    $feature->{source} = $new_source;
    
    # Adjust the key, too.
    $key = "$new_method:$new_source";
  }


  # Cleaning: Select gene features are not complete in the GFF. Fix them.
  if (eval { $converter->{keys_to_add_gene}->{$key} }) {
    my $transcript = $feature->{attributes}->{Transcript};
    if (!$transcript) {
      print $converter->logs('not_parsed') "No Transcript for $key: $line\n";
      next;
    }

    my $gene = $feature->{attributes}->{Gene};
    if ($gene) {
      print $converter->logs('not_parsed') "Gene exists for $key: $line\n";
      next;
    }
    $feature->{attributes}->{Gene} = $transcript;
  }

  $converter->add_gene_and_cds($feature) or next;
  
  # Should we use this feature to generate gene and cds lookups?
  if ($converter->transcript_index_features($key) || $converter->cds_index_features($key)) {
    my $gene       = $attributes->{Gene};
    my $transcript = $attributes->{Transcript};
    my $cds        = $attributes->{CDS};
    
    # Is there an appropriate *Pep entry?
    my $wormpep = $converter->get_peptide_id($attributes);
    
    # Sanity check
    if (($converter->transcript_index_features($key) && !$transcript)
	||
	($converter->cds_index_features($key) && !$cds)) {
      print $converter->logs('log') "Invalid index: $line\n";
    }
    
    # Remove attributes that we have already examined.
    foreach my $attribute ([qw(Gene Transcript CDS),$converter->peptide_identifiers]) {
      delete $attributes->{$attribute} if $attributes->{$attribute};
    }
    
    # Record remaining attributes, associating them with either
    # a transcript or a CDS.
    foreach my $attribute (keys %{$attributes}) {
      my $value = $attributes->{$attribute};
      
      if ($converter->transcript_index_features($key)) {
	$converter->add_transcript_attributes($transcript,$attribute,$value);
      }
      
      if ($converter->cds_index_features($key)) {
	$converter->add_cds_attributes($cds,$attribute,$value);
      }
    }
    
    $converter->populate_indices($gene,$transcript,$cds,$wormpep);
    
    print $converter->logs('discard') $line . "\n";
    next;
  }
  
  elsif ($converter->gene_features($key)) {
    my $transcript = $attributes->{Transcript};
    print $converter->logs('log') "No Transcript: $line\n" unless $transcript;
    delete $attributes->{Transcript};
    
    #
    #        # [*** briggsae exception ***]	
    #        if (!$transcript && $attributes->{CDS}) {
    #	   if ($species =~ /elegans/) {
    #	       $transcript = $attributes->{CDS};
    #	       print $LOG "Added Transcript from CDS: $line\n";
    #	   }
    #	}
    
    # It might be necessary to add the transcript ID from the CDS, regardless of the species
    if (!$transcript && $attributes->{CDS}) {
      $transcript = $attributes->{CDS};
      print $converter->logs('log') "Added Transcript from CDS: $line\n";
    }
    
    # Preserve original feature as an exon, link it to Transcript
    $attributes->{Parent} = "Transcript:$transcript" if $transcript;
    
    # Create the Transcript
    $converter->build_transcript($ref,$source,$start,$end,$score,$strand,undef,{ID => "Transcript:$transcript"});
    
    # Make a copy of the feature a CDS (only for coding_exon)
    if ($method eq 'coding_exon') {
      my $cds = $attributes->{CDS};
      print $converter->logs('log') "No CDS: $line\n" unless $cds;
      delete $attributes->{CDS};
      
      my %cds_attributes = %{$attributes};
      delete $cds_attributes{Parent};
      $cds_attributes{ID} = "CDS:$cds";
      
      my $cds_feature = {
			 ref        => $ref,
			 source     => $source,
			 method     => 'CDS',
			 start      => $start,
			 end        => $end,
			 score      => $score,
			 strand     => $strand,
			 phase      => $phase,
			 attributes => \%cds_attributes,
			};
      
      # Notify when no phase
      print $converter->logs('log') "No phase for cds: $line\n" 
	if (!defined $phase || $phase eq '.');
      
      push @CDS, $cds_feature;
    }
  }
  
  # Build up a CDS feature
  elsif ($converter->predicted_cds_features($key)) {
    my $cds = $attributes->{CDS} || $attributes->{Transcript};
    delete $attributes->{CDS};
    delete $attributes->{Transcript};
    
    # Discard when no CDS
    if (!$cds) {
      print $converter->logs('not_parsed') "no-cds: $line\n"; 
      next;
    }
    
    # Discard when no phase
    if (!defined $phase || $phase eq '.') {
      print $converter->logs('not_parsed') "no-phase-for-cds: $line\n"; 
      next;
    }
    
    # Convert this into a CDS feature
    $attributes->{ID}  = "CDS:$cds";
    $feature->{method} = 'CDS';
    $method            = $feature->{method};
    
    #         # Create a placeholder mRNA - create parent
    #         $attributes->{Parent} = "Transcript:$cds";
    # 
    #         # For each coding_exon, create a CDS part
    #         if ($method eq 'coding_exon') {
    #             # Discard when no phase
    #             if (!defined $phase || $phase eq '.') {
    #                 print $converter->logs('not_parsed') "no-phase-for-cds: $line\n"; 
    #                 next;
    #             }
    # 
    #             # Create a CDS feature
    #             my $cds_feature = {
    #                 ref         => $ref,
    #                 source      => $source,
    #                 method      => 'CDS',
    #                 start       => $start,
    #                 end         => $end,
    #                 score       => $score,
    #                 strand      => $strand,
    #                 phase       => $phase,
    #                 attributes  => {%$attributes},
    #             };
    #             $cds_feature->{attributes}->{ID}     = "CDS:$cds";
    #             $cds_feature->{attributes}->{Parent} = "Transcript:$cds";
    # 
    #             push @CDS, $cds_feature;
    #         }
    #         
    #         # Create a placeholder mRNA - create the mRNA feature
    #         $TRANSCRIPT{$cds}{ref}    = $ref;
    #         $TRANSCRIPT{$cds}{source} = $source;
    #         $TRANSCRIPT{$cds}{method} = 'mRNA';
    #         $TRANSCRIPT{$cds}{start}  = $start
    #           if !exists $TRANSCRIPT{$cds}{start}
    #           or $TRANSCRIPT{$cds}{start} > $start;
    #         $TRANSCRIPT{$cds}{end} = $end
    #           if !exists $TRANSCRIPT{$cds}{end}
    #           or $TRANSCRIPT{$cds}{end} < $end;
    #         $TRANSCRIPT{$cds}{score}      = $score;
    #         $TRANSCRIPT{$cds}{strand}     = $strand;
    #         $TRANSCRIPT{$cds}{phase}      = $phase;
    #         $TRANSCRIPT{$cds}{attributes} =
    #           { ID => "Transcript:$cds", 
    #             placeholder_transcript => 1
    #            };
    #     
    #         # Populate indexes
    #         $TRANSCRIPT2GENE{$cds} = $cds;
    #         $TRANSCRIPT2CDS{$cds}  = $cds;
  }
  
  elsif ($converter->ncrna_features($key)) {
    my $transcript = $attributes->{Transcript};
    print $converter->logs('log') "No Transcript: $line\n" unless $transcript;
    delete $attributes->{Transcript};
    
    # Preserve original feature as an exon, link it to Transcript
    $attributes->{Parent} = "Transcript:$transcript";
    
    # Create the Transcript
    $converter->build_transcript($ref,$source,$start,$end,$score,$strand,undef,undef);
  }
  
  elsif ($converter->only_mrna_features($key)) {
    my $transcript = $attributes->{Transcript};
    delete $attributes->{Transcript} if exists $attributes->{Transcript};
    
    my $gene = $attributes->{Gene};
    delete $attributes->{Gene} if exists $attributes->{Gene};
    
    # Exception to indexing
    if ($transcript && $gene) {
      $converter->transcript2gene($transcript,$gene);
    }
    else {
      print $converter->logs('not_parsed') "ERROR: Incomplete info: $line\n";
      next;
    }
    
    print $converter->logs('log') "No transcript: $line\n" unless $transcript;
    
    print $converter->logs('log') "Transcript exists: $line\n" if $TRANSCRIPT{$transcript};
    
    $attributes->{ID} = "Transcript:$transcript" if $transcript;

    my @alias;
    foreach my $tag (qw(Alias Gene)) {
      if ($attributes->{$tag}) {
	push @alias, $attributes->{$tag};
	delete $attributes->{$tag};
      }
    }
    
    $attributes->{Alias} = join(',', @alias) if @alias;

    # Create the Transcript
    $converter->build_transcript($ref,$source,$start,$end,$score,$strand,$phase,$attributes);
    next;
  }
  
  elsif ($REGULAR_FEATURES{$key}) {
    # DO NOT DO ANYTHING
  }
  
  elsif ($converter->pseudogene_features($key)) {
    my $pseudogene = $attributes->{Pseudogene};
    delete $attributes->{Pseudogene};
    
    # Discard when no pseudogene
    if (!$pseudogene) {
      print $converter->logs('not_parsed') "no-pseudogene: $line\n"; 
      next;
    }
    
    my $id = "Pseudogene:$pseudogene";
    
    if ($method eq 'exon') {
      $feature->{attributes}->{ID} = $id;
      $feature->{method} = 'pseudogene';
      $method            = $feature->{method};
      
      # THIS HASN'T BEEN HANDLED YET.
      $PSEUDOGENES_BY_EXON{$id}{start} = $start if
	!$PSEUDOGENES_BY_EXON{$id}{start} 
	  or $start < $PSEUDOGENES_BY_EXON{$id}{start};
      $PSEUDOGENES_BY_EXON{$id}{end} = $end if
	!$PSEUDOGENES_BY_EXON{$id}{end} 
	  or $end > $PSEUDOGENES_BY_EXON{$id}{end};
    }
    
    elsif ($method eq 'Pseudogene') {
      $PSEUDOGENES_BY_BLOCK{$id}{start} = $start if
	!$PSEUDOGENES_BY_BLOCK{$id}{start} 
	  or $start < $PSEUDOGENES_BY_BLOCK{$id}{start};
      $PSEUDOGENES_BY_BLOCK{$id}{end} = $end if
	!$PSEUDOGENES_BY_BLOCK{$id}{end} 
	  or $end > $PSEUDOGENES_BY_BLOCK{$id}{end};
      print $converter->logs('discard') "$line\n";
      next;
      #            $feature->{method}                   = 'region';
      #            $feature->{attributes}->{ID}         = $id;
      #            $feature->{attributes}->{pseudogene} = 1;
    }
  }
  
  elsif ($DISCARD_FEATURES{$key}) {
    print $converter->logs('discard') "$line\n";
    next;
  }

  # Mystery features
  else {
    print $converter->logs('discard') "not-listed: $line\n";
    next;
  }
  
  if ($SOFA_TERMS{$method}) {
    $feature->{method} = $SOFA_TERMS{$method};
  }
  
  elsif ($DEFAULT_SOFA_TERMS->{$method}) {
    
    # OK;
  }
  else {
    print $converter->logs('no_term') "$line\n";
    next;
  }
  
  # Dump feature if it passes the filters
  dump_feature($feature);
}


# Check if all pseudogene "gene models" have been dumped
foreach my $id (keys %PSEUDOGENES_BY_EXON) {
  if (!$PSEUDOGENES_BY_BLOCK{$id}) {
    print $converter->logs('log') "Pseudogene has gene model but not block feature: $id\n";
  }
}

foreach my $id (keys %PSEUDOGENES_BY_BLOCK) {
  if (!$PSEUDOGENES_BY_EXON{$id}) {
    print $converter->logs('log') "Pseudogene has block feature but not gene model: $id\n";
  }
  if ($PSEUDOGENES_BY_EXON{$id}{start} != $PSEUDOGENES_BY_EXON{$id}{start}
      or
      $PSEUDOGENES_BY_EXON{$id}{end} != $PSEUDOGENES_BY_EXON{$id}{end}) {
    print $converter->logs('log') "Pseudogene block feature and not gene model coordinates do not match: $id\n";
  }
}

# Build 1-to-many indexes
foreach my $transcript ($converter->transcript2gene) {
  my $gene = $converter->transcript2gene{$transcript};
  $converter->gene2transcript($gene,$transcript);
}

foreach my $transcript ($converter->transcript2cds) {
  my $cds = $converter->transcript2cds($transcript);
  $converter->cds2transcript($cds,$transcript);
}


# Dump transcripts & prepare genes
foreach my $transcript ($converter->transcripts) {
  my $gene = $converter->transcript2gene($transcript);
  print $converter->logs('log') "No Gene for Transcript: $transcript\n" unless $gene;

  my $cds = $converter->transcript2cds($transcript);

  # WHAT?  NEED TO HANDLE THIS CASE
  # HACK - STEPPING INTO OBJECT'S DATA STRUCTURE
  print $converter->logs('log') "No CDS for Transcript: $transcript\n" 
    if (!$cds && $converter->{transcripts}->{$transcript}->{method} ne 'ncRNA');

  my $wormpep = $converter->cds2protein($cds) if $cds;
  print $converter->logs('log') "No Wormpep for Transcript: $transcript; CDS: $cds\n"
    if ($cds && !$wormpep);



  # DONE TO HERE


  
  # Add attributes
  my $add_attributes = $TRANSCRIPT_ATTRIBUTES{$transcript};
  if ($add_attributes) {
    foreach my $add_attribute (keys %$add_attributes) {
      if ($TRANSCRIPT{$transcript}{attributes}{$add_attribute}) {
	print $converter->logs('log') "replacing attribute ($add_attribute) for transcript ($transcript)!\n";
      }
      $TRANSCRIPT{$transcript}{attributes}{$add_attribute} 
	= $add_attributes->{$add_attribute};
    }
  }

  $TRANSCRIPT{$transcript}{attributes}{Parent}  = "Gene:$gene" if $gene;
  $TRANSCRIPT{$transcript}{attributes}{CDS}     = "$cds"       if $cds;
  $TRANSCRIPT{$transcript}{attributes}{WormPep} = "$wormpep"   if $wormpep;
#  $TRANSCRIPT{$transcript}{attributes}{Brigpep} = "$brigpep"   if $brigpep;

  if ($gene) {
    $GENE{$gene}{ref}    = $TRANSCRIPT{$transcript}{ref};
    $GENE{$gene}{source} = $TRANSCRIPT{$transcript}{source};
    $GENE{$gene}{method} = 'gene';
    $GENE{$gene}{start}  = $TRANSCRIPT{$transcript}{start}
      if !exists $GENE{$gene}{start}
	or $GENE{$gene}{start} > $TRANSCRIPT{$transcript}{start};
    $GENE{$gene}{end} = $TRANSCRIPT{$transcript}{end}
      if !exists $GENE{$gene}{end}
	or $GENE{$gene}{end} < $TRANSCRIPT{$transcript}{end};
    $GENE{$gene}{score}      = $TRANSCRIPT{$transcript}{score};
    $GENE{$gene}{strand}     = $TRANSCRIPT{$transcript}{strand};
    $GENE{$gene}{phase}      = '.';
    $GENE{$gene}{attributes} = {ID => "Gene:$gene"};
    if ($TRANSCRIPT{$transcript}{attributes}{placeholder_transcript}) {
      $GENE{$gene}{attributes}{placeholder_gene} = 1;
    }
  }

  my $method = $TRANSCRIPT{$transcript}{method};
  if ($SOFA_TERMS{$method}) {
    $TRANSCRIPT{$transcript}{method} = $SOFA_TERMS{$method};
  }
  elsif ($DEFAULT_SOFA_TERMS->{$method}) {
    
    # OK;
  }
  else {
    print $converter->logs('no_term') "transcript:$transcript\n";
    next;
  }

  dump_feature($TRANSCRIPT{$transcript});
}

# Dump genes
foreach my $gene (sort keys %GENE) {
  dump_feature($GENE{$gene});
}

# Dump CDS parts
foreach my $cds_feature (@CDS) {
  my $cds_id = $cds_feature->{attributes}->{ID};
  $cds_id =~ s/^[^:]+://;
  
#  if ($species =~ /elegans/) {
#    if ($CDS2PROTEIN{$cds_id}) {
#      $cds_feature->{attributes}->{WormPep} = $CDS2PROTEIN{$cds_id};
#    }
#    else {
#      print $converter->logs('log') "No WormPep for CDS: $cds_id\n";
#    }
#  }
#
#    if ($species ne "c_elegans") {
#        if ($CDS2BRIGPEP{$cds_id}) {
#            $cds_feature->{attributes}->{Brigpep} = $CDS2BRIGPEP{$cds_id};
#        }
#        else {
#            print $converter->logs('log') "No Brigpep for CDS: $cds_id\n";
#        }
#    }

  if ($CDS2PROTEIN{$cds_id}) {
    $cds_feature->{attributes}->{WormPep} = $CDS2PROTEIN{$cds_id};
  } else {
    print $converter->logs('log') "No WormPep for CDS: $cds_id\n";
  }

  # Add attributes
  my $add_attributes = $CDS_ATTRIBUTES{$cds_id};
  if ($add_attributes) {
    foreach my $add_attribute (keys %$add_attributes) {
      if ($cds_feature->{attributes}{$add_attribute}) {
	print $converter->logs('log') "replacing attribute ($add_attribute) for cds ($cds_id)!\n";
      }
      $cds_feature->{attributes}->{$add_attribute} 
	= $add_attributes->{$add_attribute};
    }
  }
  
  my @transcript = @{$CDS2TRANSCRIPT{$cds_id}} if $CDS2TRANSCRIPT{$cds_id};
  my $transcript = join(',', map {"Transcript:$_"} @transcript);
  if ($transcript) {
    $cds_feature->{attributes}->{Parent} = "$transcript";
  }
  else {
    print $converter->logs('log') "No Parent for CDS: $cds_id\n";
  }
  
  dump_feature($cds_feature);
}

# Add header
print $GFF "##gff-version 3\n";
foreach my $ref (sort {$CHROMOSOME_NAMES{$a} <=> $CHROMOSOME_NAMES{$b}}
                 keys %SEQUENCE_REGION_ENDS) {
  print $converter->logs('gff') qq[##sequence-region $ref 1 $SEQUENCE_REGION_ENDS{$ref}\n];
}      

foreach my $ref (sort {$CHROMOSOME_NAMES{$a} <=> $CHROMOSOME_NAMES{$b}}
                 keys %SEQUENCE_REGION_ENDS) {
#    if ($species =~ /elegans|briggsae/) {
#	print $GFF join("\t", $ref, 'Reference', 'chromosome', 1, $SEQUENCE_REGION_ENDS{$ref}, '.', '+', '.', qq[ID=$ref;Name=$ref]) . "\n";
#    } else {
	print $converter->logs('gff') join("\t", $ref, 'Reference', 'chromosome', 1, $SEQUENCE_REGION_ENDS{$ref}, '.', '+', '.', qq[ID=$ref;Name=$ref]) . "\n";
#    }
}      

# Close all filehandles
close $NOT_PARSED;
close $TMP_GFF;
close $GFF;
close $LOG;
close $DISCARD;
close $NO_TERM;
close $DUPLICATE;

#  system("rm -rf /tmp/$file*") if PURGE;

# Append file
my $cmd = $sort ? qq[sort -k1,1 -k3,3 -k2,2 -k4,4n -T /tmp $output_dir/tmp.gff >> $output]
                : qq[cat $output_dir/tmp.gff >> $output];
system($cmd) and croak("Cannot sort file ($cmd)!");

# print Dumper(\%TRANSCRIPT_ATTRIBUTES);
# print Dumper(\%CDS_ATTRIBUTES);





sub dump_feature {
  my ($feature) = @_;
  
  # Cleaning: no feature attributes? set a placeholder for formatting.
  if (!scalar(keys %{$feature->{attributes}})) {
    $feature->{attributes}->{placeholder_attribute} = 1;
  }

  my $ref        = $feature->{ref};
  my $source     = $feature->{source};
  my $method     = $feature->{method};
  my $start      = $feature->{start};
  my $end        = $feature->{end};
  my $score      = $feature->{score};
  my $strand     = $feature->{strand};
  my $phase      = $feature->{phase};
  my $attributes = $feature->{attributes};
  
  my $reserved_attributes;
  my $other_attributes;
  foreach my $tag (keys %{$attributes}) {
    if ($TAG_ORDER{$tag}) {
      $reserved_attributes->{$tag} = $attributes->{$tag};
    }
    else {
      $other_attributes->{lc($tag)} = $attributes->{$tag};
    }
  }

  my @reserved_attributes = map { "$_=" . $reserved_attributes->{$_} }
    sort { $TAG_ORDER{$b} <=> $TAG_ORDER{$b} } keys %{$reserved_attributes};

  my @other_attributes = map { "$_=" . $other_attributes->{$_} }
    sort keys %{$other_attributes};

  my $attributes_string =
    join(';', @reserved_attributes, @other_attributes);

  my $feature_string = join(
			    "\t",   $ref,    $source, $method, $start, $end,
			    $score, $strand, $phase,  $attributes_string
			   );

  # Record sequence region end
  if (!$SEQUENCE_REGION_ENDS{$ref}) {
    $SEQUENCE_REGION_ENDS{$ref} = 1;
  }
  if ($end > $SEQUENCE_REGION_ENDS{$ref}) {
    $SEQUENCE_REGION_ENDS{$ref} = $end;
  }
  
  # If this is a CDS, have we seen it before?
  if ($feature->{method} eq 'CDS') {
    my $cds_signature = md5($feature_string);
    if ($CDS_MD5_LIST{$cds_signature}) {
      $feature_string = undef;
    }
    $CDS_MD5_LIST{$cds_signature} = 1;
  }
  
  print $converter->logs('tmp_gff') $feature_string . "\n" if defined $feature_string;
  
  return 1;
}



sub escape {
    my $toencode = shift;
    return $toencode unless defined $toencode;
    $toencode = unescape($toencode);    # Make safe
#    $toencode =~ s/([^a-zA-Z0-9_. :+-\*])/uc sprintf("%%%02x",ord($1))/eg;
    $toencode =~ s/([,;=\t])/uc sprintf("%%%02x",ord($1))/eg;
    $toencode;
}

sub unescape {
    my $string = shift;
    return $string unless defined $string;
    $string =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    return $string;
}

sub parse_sofa {
    my ($file) = @_;

    my $mode = 'Placeholder';

    open(FILE, $file) or die "Cannot open file ($file): $!";

    my %terms;

    while (my $line = <FILE>) {
        chomp $line;
        next unless $line;

        if ($line =~ /^\[([^\[\]]+)\]/) {
            $mode = $1;
            if (   $mode ne 'Term'
                && $mode ne 'Typedef'
                && $mode ne 'Placeholder') {
                die "Cannot parse sofa file ($line)";
            }
        }

        if ($mode eq 'Term' and $line =~ /^name:\s+(.+)/) {
            $terms{$1} = 1;
        }
    }

    close FILE;

    if (scalar(keys %terms) < 30)
    {    # Something *most likely* went wrong in acquiring/processing sofa
        die "Cannot retrieve/parse SOFA file!";
    }

    return \%terms;
}





package GFF3Converter;

use strict;
use Digest::MD5 qw(md5);

sub new {
  my ($self,$output) = @_;
  my $this = bless {},$self;

  # Track line numbers as we go.
  $this->{line_number} = 0;

  # Stash some filehandles
  my $output_dir = "$output-gff2togff3-conversion";
  system("mkdir $output_dir");
  
  open(DUPLICATE, ">$output_dir/duplicate") or croak("Cannot write file ($output_dir/duplicate): $!");
  open(NOT_PARSED, ">$output_dir/not_parsed") or croak("Cannot write file ($output_dir/not_parsed): $!");
  open(TMP_GFF, ">$output_dir/tmp.gff") or croak("Cannot write file ($output_dir/tmp.gff): $!");
  open(GFF, ">$output")                 or croak("Cannot write file ($output): $!");
  open(LOG, ">$output_dir/log")         or croak("Cannot write file ($output_dir/log): $!");
  open(DISCARD, ">$output_dir/discard") or croak("Cannot write file ($output_dir/discard): $!");
  open(NO_TERM, ">$output_dir/no_term") or croak("Cannot write file ($output_dir/no_term): $!");

  $this->{logs}->{duplicate_lines} = \*DUPLICATE;
  $this->{logs}->{not_parsed}      = \*NOT_PARSED;
  $this->{logs}->{tmp_gff}         = \*TMP_GFF;
  $this->{logs}->{gff}             = \*GFF;
  $this->{logs}->{log}             = \*LOG;
  $this->{logs}->{discard}         = \*DISCARD;
  $this->{logs}->{no_term}         = \*NO_TERM;

  # Keys to convert to SOFA compliant terms
  $this->{features_to_convert} = (
				  'miRanda:binding_site'                       => 'binding_site:miRanda',
				  'PicTar:binding_site'                        => 'binding_site:PicTar',
				  'ALLELE:.'                                   => 'sequence_variant:misc_feature',
				  'misc_feature:Deletion_and_insertion allele' => 'complex_substitution:misc_feature',
				  'oligo:.'                                    => 'oligo:misc_feature',
				  'RNAz:ncRNA'                                 => 'ncRNA:RNAz',
				  'Clone_left_end:.'                           => 'Clone_left_end:misc_feature',
				  'Clone_right_end:.'                          => 'Clone_right_end:misc_feature',
				 );

  # Keys to clean if briggsae [*** briggsae exception ***]
  #if ($species =~ /elegans/) {
  #} else {
  #    $KEYS_TO_CONVERT{'coding_exon:curated'} = 'coding_exon:Coding_transcript';
  #    $KEYS_TO_CONVERT{'intron:curated'}      = 'intron:Coding_transcript';
  #}
  
  # Does this break C. elegans conversion?
  $this->{features_to_convert}->{'coding_exon:curated'} = 'coding_exon:Coding_transcript';
  $this->{features_to_convert}->{'intron:curated'}      = 'intron:Coding_transcript';

  # Keys to add gene/cds, if found, convert feature into a gene/cds
  # These are the majority of annotated genes.
  $this->{keys_to_add_gene_and_cds} = ( protein_coding_primary_transcript:Coding_transcript => 1);

  # Keys to add gene
  # If any of these are found, we will add the feature as a gene
  $this->{keys_to_add_gene} = map { $_ => 1 } qw(
						tRNA_primary_transcript:tRNAscan-SE-1.23
					      ncRNA:RNAz
					       );

  # Create unique IDs for targets
  $this->{max_target_id_number} = 0;

  # Gene entries include a reference to the corresponding peptide
  # using an historically arcane nomenclature.
  # This will need to be modified for each new genome.
  $this->{peptide_identifiers} = map { $_ => 1 } qw(WormPep BrigPep RemPep Jappep BrePep);

  # The following entries correspond to Transcripts in WormBase GFF2
  $this->{transcript_index_features} = map { $_ => 1 }
    qw(
      Transcript:Coding_transcript
    Transcript:ncRNA
  Transcript:snlRNA
 miRNA_primary_transcript:miRNA
 ncRNA_primary_transcript:ncRNA
 nc_primary_transcript:Non_coding_transcript
 protein_coding_primary_transcript:Coding_transcript
 rRNA_primary_transcript:rRNA
 scRNA_primary_transcript:scRNA
 snoRNA_primary_transcript:snoRNA
 snRNA_primary_transcript:snRNA
 tRNA_primary_transcript:tRNA
 tRNA_primary_transcript:tRNAscan-SE-1.23
     );
  
  # The following entries correspond to CDSs in WormBase GFF2
  $this->{cds_index_features} = map { $_ => 1 }
    qw(
      CDS:curated
    CDS:Genefinder
  CDS:GeneMarkHMM
 CDS:history
 CDS:mSplicer_orf
 CDS:mSplicer_transcript
 CDS:twinscan
     );

  # Features taht belong to predicted CDSs
  $this->{predicted_cds_features} = map { $_ => 1 } qw(
						      coding_exon:Genefinder
						    coding_exon:GeneMarkHMM
						  coding_exon:history
						coding_exon:mSplicer_orf
					      coding_exon:mSplicer_transcript
					    coding_exon:twinscan
						     );
  
  # Feature list (make an mRNA & a CDS for each of these)
  $this->{gene_features} = map { $_ => 1 } qw(
					     coding_exon:Coding_transcript
					   intron:Coding_transcript
					 five_prime_UTR:Coding_transcript
				       three_prime_UTR:Coding_transcript
					    );

  # Feature list (make only a Transcript for each of these)
  $this->{ncrna_features) = map { $_ => 1 } qw(
					      exon:miRNA
					    exon:ncRNA
					  intron:ncRNA  
					exon:Non_coding_transcript
				      intron:Non_coding_transcript
				    exon:rRNA
				  exon:scRNA
				exon:snoRNA
			      exon:snRNA
			    exon:snlRNA
			  exon:tRNA
			exon:tRNAscan-SE-1.23
					     );
  $this->{only_mrna_features} = ('ncRNA:RNAz' => 1);

  $this->{pseudogene_features} = map { $_ => 1 } qw(
						     exon:Pseudogene
						   Pseudogene:Pseudogene
						 exon:history
					       Pseudogene:history
						  );

  # Lookup tables for attributes
  $this->{transcript_attributes} = {};
  $this->{cds_attributes}        = {};

  return $this;
}

sub pseudogene_features {
  my ($self,$key) = @_;
  return 1 if (eval {$self->{pseudogene_features}->{$key}));
  return 0;
}

# Create lookup tables
sub populate_indices {
  my ($self,$gene,$transcript,$cds,$wormpep) = @_;
  $self->{transcript2gene}->{$transcript} = $gene if ($transcript && $gene);
  $self->{transcript2cds}->{$transcript}  = $cds  if ($transcript && $cds);
  $self->{cds2protein}->{$cds}            = $wormpep if ($cds && $wormpep);
}

# Getter / setter
sub transcript2gene {
  my ($self,$transcript,$gene) = @_;
  unless ($transcript) {
    my @keys = keys %{$self->{transcript2gene}};
    return @keys;
  }
  if ($gene) {  # setter
    $self->{transcript2gene}->{$transcript} = $gene;
  } else {      # getter
    my $gene = $self->{transcript2gene}->{$transcript};
    return $gene;
  }
}

# Getter / setter
sub transcript2cds {
  my ($self,$transcript,$cds) = @_;
  unless ($transcript) {
    my @keys = keys %{$self->{transcript2cds}};
    return @keys;
  }
  if ($cds) {  # setter
    $self->{transcript2cds}->{$transcript} = $cds;
  } else {     # getter
    my $cds = $self->{transcript2gene}->{$transcript};
    return $cds;
  }
}

# Getter / setter
sub gene2transcript {
  my ($self,$gene,$transcript) = @_;
  unless ($gene) {
    my @keys = keys %{$self->{gene2transcript}};
    return @keys;
  }
  if ($transcript) {  # setter
    $self->{gene2transcript}->{$gene} = $transcript;
  } else {     # getter
    my $transcript = $self->{gene2transcript}->{$gene};
    return $transcript;
  }
}

sub transcripts {
  my ($self) = shift;
  my @transcripts = sort keys %{$self->{transcripts}};
  return @transcripts;
}

# Getter / setter
sub cds2transcript {
  my ($self,$cds,$transcript) = @_;
  unless ($cds) {
    my @keys = keys %{$self->{cds2transcript}};
    return @keys;
  }
  if ($transcript) {  # setter
    $self->{cds2transcript}->{$cds} = $transcript;
  } else {     # getter
    my $transcript = $self->{cds2transcript}->{$cds};
    return $transcript;
  }
}

# Getter / setter
sub cds2protein {
  my ($self,$cds,$protein) = @_;
  unless ($cds) {
    my @keys = keys %{$self->{cds2protein}};
    return @keys;
  }
  if ($protein) {  # setter
    $self->{cds2protein}->{$cds} = $protein;
  } else {     # getter
    my $protein = $self->{cds2protein}->{$cds};
    return $protein;
  }
}

sub gene_features {
  my ($self,$key) = @_;
  my $gene = $self->{gene_features}->{$key};
  return $gene || undef;
}

sub predicted_cds_features {
  my ($self,$key) = @_;
  return 1 if (eval { $self->{predicted_cds_features}->{$key} } );
  return 0;
}

sub ncrna_features {
  my ($self,$key) = @_;
  return 1 if (eval { $self->{ncrna_features}->{$key} } );
  return 0;
}


sub only_mrna_features {
  my ($self,$key) = @_;
  return 1 if (eval { $self->{only_mrna_features}->{$key} } );
  return 0;
}

sub build_transcript {
  my ($self,$source,$start,$end,$score,$strand,$phase,$attibutes) = @_;
  my $old_start = eval { $self->{transcripts}->{$transcript}->{start} };
  $start ||= $old_start;
  $start   = $old_start if $old_start > $start;
  
  my $old_end = eval { $self->{transcripts}->{$transcript}->{end} };
  $end ||= $old_end;
  $end   = $old_end if $old_end < $end;

  $phase ||= '.';

  $self->{transcripts}->{$transcript} = (
					 ref        => $ref,
					 source     => $source,
					 method     => 'mRNA',
					 start      => 'start',
					 end        => 'end',
					 score      => $score,
					 strand     => $strand,
					 phase      => '.',
					 attributes => $attributes,
					);
}

sub add_transcript_attributes {
  my ($self,$transcript,$attribute,$value) = @_;
  $self->{transcript_attributes}->{$transcript}->{$attribute} = $value;
}

sub add_cds_attributes {
  my ($self,$cds,$attribute,$value) = @_;
  $self->{cds_attributes}->{$cds}->{$attribute} = $value;
}


# Various indexes
sub transcript_index_features {
  my ($self,$key) = @_;
  my $transcript = $self->{transcript_index_features}->{$key};
  return $transcript || undef;
}

sub cds_index_features {
  my ($self,$key) = @_;
  my $cds = $self->{cds_index_features}->{$key};
  return $cds || undef;
}


sub peptide_identifiers {
  my $self->shift;
  my @ids = keys %{$self->{peptide_identifiers}};
  return @ids;
}

# Look up a suitable peptide ID from an entry.
# Unfortunately, these are all keyed by different names
sub get_peptide_id {
  my ($self,$attributes) = @_;
  foreach ($self->peptide_identifiers) {
    $wormpep = $attributes->{$_};
    return $wormpep if $wormpep;
  }
  return;
}

sub check_for_duplicate_lines {
  my ($self,$line) = @_;

  $self->log_line();

  # Ignore lines that we have seen before
  my $digest = md5($line);
  if ($self->{lines_seen}->{$digest}) {
    print $self->logs('duplicate_lines') "$line\n";
    return 0;
  } else {
    $self->{lines_seen}->{$digest} = 1;
    return 1;
  }
}

sub log_this_line {
  my $self = shift;
  $self->{line_number}++;
  
  print STDERR "Line: $self->{line_number} " . time . "\n" 
    if $self->{line_number} % 100000 == 0;
}

sub logs {
  my ($self,$log) = @_;
  return $self->{logs}->{$log};
}


sub parse_line {
  my ($self,$line) = @_;
  
  # Split GFF2 into its component fields.
  my ($ref,$source,$method,$start,$end,$score,$strand,$phase,$attributes) = split("\t", $line);
  
  # feature_signature id needed for Target ids
  my $feature_signature = join(':', $ref, $source, $method, $strand);
  
  $attributes = parse_attributes($attributes, $feature_signature);
  
  # No attributes?  Let's ignore this line. Return undef so we will ignore this line.
  return undef if (!defined $attributes);
  
  my $feature = {
		 ref        => $ref,
		 source     => $source,
		 method     => $method,
		 start      => $start,
		 end        => $end,
		 score      => $score,
		 strand     => $strand,
		 phase      => $phase,
		 attributes => $attributes,
		};
  return $feature;
}

sub parse_attributes {
  my ($attributes, $feature_signature) = @_;
  
  my %attributes;
  return \%attributes unless $attributes;
  
  # Parse target attributes
  if ($attributes =~ /^Target/) {
    $attributes =~ s/Target "([^\"]+)" ([\d-]+) ([\d-]+)\s*\;*\s*//;
    
    my ($target_sequence, $target_start, $target_end) = ($1, $2, $3);
    
    unless ($target_sequence && defined $target_start && defined $target_end) {
      print $self->logs('not_parsed') "unparseable-target: ";
      return undef;
    }
    
    my $target_strand = '+';
    
    if ($target_start < 0 or $target_end < 0) {
      print $self->logs('not_parsed') "negative-target: ";
      return undef;
    }
    
    if ($target_end < $target_start) {
      $target_strand = '-';
      ($target_start, $target_end) = ($target_end, $target_start);
    }
    
    $attributes{Target} =
      "$target_sequence $target_start $target_end $target_strand";
    
    $attributes =~ s/Target[^;]//;
    
    my $target_signature =
      join(':', $feature_signature, $target_sequence, $target_strand);
    
    my $target_id = eval { $self->{target_ids}->{$target_signature} };
    unless ($target_id) {
      $self->{max_target_id_number}++;
      $target_id = 'Target:' . sprintf('%.6u', $self->{max_target_id_number});
      $self->{target_ids}->{$target_signature} = $target_id;
    }
    $attributes{ID} = $target_id;
  }
  
  # Clean free text entries
  if ($attributes =~ s/;\s*; .+//) {
    print $self->logs('log') "Discarded after double semicolon: $attributes\n";
  }
  
  # Clean text
  $attributes =~ s/[\s;]+$//;
  
  # NECESSARY?
  #    # Clean free-text attribute in briggsae gff
  #    $attributes =~ s/ (orthologous to [^\;\s]+ by [^\;]+) /Note "$1"/;
  
  # Escape semi-colon
  $attributes =~ s/(\"[^\";]*;[^\";]*\"[^\";]*);/$1 %3B/g;
  
  # Escape comma
  $attributes =~ s/,/%2C/g;
  
  # Add Transcript for RNAz predictions
  $attributes =~ s/(RNAz-\d+)/Transcript $1/;
  
  # Fill empty fields
  $attributes =~ s/;\s*(\S+)\s*;/; $1 1 ;/g;
  $attributes =~ s/;\s*(\S+)\s*;/; $1 1 ;/g;
  
  # Fill empty fields
  $attributes =~ s/^\s*(\S+)\s*;/$1 1 ;/g;
  $attributes =~ s/;\s*(\S+)\s*$/; $1 1/g;
  $attributes =~ s/^\s*(\S+)\s*$/$1 1/g;
  
  my @tokens = quotewords('\s*;\s*|\s+', 0, $attributes);
  
  while (@tokens) {
    my $tag   = shift @tokens;
    my $value = escape(shift @tokens);
    
    # Force *ALL* peptides to be called WormPep regardless of their genome.
    # Why would I do this?  This is goofy. Keep the identifier the same.
    # if (defined $self->{peptide_identifiers}->{$tag}) {
    #   $tag = 'WormPep';
    # }
    
    $attributes{$tag} =
      defined $attributes{$tag}
	? $attributes{$tag} . ",$value"
          : $value;
  }  return \%attributes;
}


# Cleaning: Features should start at 1, not 0.
sub adjust_start_and_stop {
  my ($self,$feature) = @_;
  if ($feature->{start} == 0) {
    $feature->{start}++;
    $feature->{end}++;
    print $self->logs('log') "zero-based feaure shifted: $line\n";
  }
}

sub features_to_convert {
  my ($self,$key) = @_;
  return eval { $self->{features_to_convert}->{$key} };
}


# The lookup key is comprised of method and source.
# It's used to determine how to handle different feature types.
sub build_lookup_key {
  my ($self,$feature) = @_;
  return $feature->{method} . ":" . $feature->{source};
}

# Add a gene and CDS entry when appropriate.
sub add_gene_and_cds {
  my ($self,$feature) = @_;

  my $key = $self->build_lookup_key($feature);
  if ($self->{keys_to_add_gene_and_cds}->{$key}) {
    my $transcript = $feature->{attributes}->{Transcript};
    if (!$transcript) {
      print $converter->logs('not_parsed') "No Transcript for $key: $line\n";
      return 0;
    }

    my $gene_cds = $feature->{attributes}->{Gene} || $feature->{attributes}->{CDS};
    if ($gene_cds) {
      print $converter->logs('not_parsed') "Gene/CDS exists for $key: $line\n";
      return 0;
    }
    
    # Try to fetch out the CDS name from the transcript ID.
    # This will (PROBABLY) break with non-elegans entries.
    # TO CHECK: Is the CDS now an ID in the group field?
    my ($cds) = $transcript =~ /^([^\.]+\.\d+[a-z]*)/;
    $feature->{attributes}->{CDS} = $cds;

    # This is just the GENE ID - supplant with WBGene IDs?
    my ($gene) = $transcript =~ /^([^\.]+\.\d+)/;
    $feature->{attributes}->{Gene} = $gene;
  }
  return 1;
}


1;
