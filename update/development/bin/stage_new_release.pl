#!/usr/bin/perl

use Moose;


# This is the staging script for a new build of WormBase.

# See for documentation
# http://wiki.wormbase.org/index.php/Updating_The_Development_Server




my @species = species_list();
foreach (@species) {

sub process_species {
    my $self = shift;
    
}


etc
etc
etc

# C. elegans
gunzip c_elegans.${RELEASE}.dna.fa.gz
perl -p -i -e 's/CHROMOSOME_//g' c_elegans.${RELEASE}.dna.fa.gz
gzip c_elegans.${RELEASE}.dna.fa.gz

# Remove introns from the GFF
./process_celegans_gff.pl --file c_elegans.${RELEASE}.gff.gz

bp_bulk_load_gff.pl --user root --pass 3l3g@nz --create --database c_elegans_WS224 --fasta c_elegans.WS224.dna.fa.gz c_elegans.WS224GBrowse.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.protein_motifs.gff.gz /usr/local/ftp/pub/wormbase/genomes/c_elegans/annotations/gff_patches/c_elegans.WS224.genetic_intervals.gff.gz


IF fasta
    ... build blast and blat

IF GFF
    ... build gbrowse



