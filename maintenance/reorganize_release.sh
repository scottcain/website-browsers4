#!/bin/bash

RELEASE=$1

# Contains an array of species names
source /home/tharris/projects/wormbase/website-admin/update/production/update.conf

FTP_ROOT=/usr/local/ftp/pub/wormbase
cd ${FTP_ROOT}/releases/$RELEASE

# Rename the genomes directory to the more accurate "species"
mv genomes species

# Flatten the hierarchy.                                                                                                       
for THIS_SPECIES in ${SPECIES}
do
    cd ${FTP_ROOT}/releases/$RELEASE/species
    cd ${THIS_SPECIES}

    # Rename gff.gz to gff2.gz
    mv genome_feature_tables/GFF2/*.${RELEASE}.gff.gz ${THIS_SPECIES}.${RELEASE}.gff2.gz

    # relocate GFF3
    mv genome_feature_tables/GFF3/*.${RELEASE}.gff3.gz ${THIS_SPECIES}.${RELEASE}.gff3.gz

    # Rename dna.fa.gz to genomic.fa.gz
    mv sequences/dna/${THIS_SPECIES}.${RELEASE}.dna.fa.gz ${THIS_SPECIES}.${RELEASE}.genomic.fa.gz

    # Rename intergenic sequences
    mv sequence/dna/intergenic_sequences.dna.gz ${THIS_SPECIES}.${RELEASE}.intergenic_sequence.fa.gz

    # Rename masked and softmasked
    mv sequences/dna/${THIS_SPECIES}_masked.${RELEASE}.dna.fa.gz ${THIS_SPECIES}.${RELEASE}.genomic._masked.fa.gz
    mv sequences/dna/${THIS_SPECIES}_softmasked.${RELEASE}.dna.fa.gz ${THIS_SPECIES}.${RELEASE}.genomic_softmasked.fa.gz

    # Save RNA
    mv sequences/rna/*${RELEASE}.gz .

    # Save the fasta for the *pep, and rename it following convention.
    mv sequences/protein/*.${RELEASE}.fa.gz ${THIS_SPECIES}.${RELEASE}.protein.fa.gz

    # Save the spliced sequences (distributed as part of wormpep?)
    cd sequences/protein
    tar xzf *.tar.gz
    cd ../../
    mv sequences/protein/*.dna* ${THIS_SPECIES}.${RELEASE}.spliced.fa.gz
    
    # Save the full wormpep package
    mv sequences/protein/*.tar.gz ${THIS_SPECIES}.${RELEASE}.wormpep_package.tar.gz

    # Save blast hits
    mv sequences/protein/best_blast* ${THIS_SPECIES}.${RELEASE}.best_blast_hits.gz

    # The letter
    mv letter.${RELEASE} letter.${RELEASE}.txt

    # Keep source directories around to make sure we have what we want to retain.
    mkdir temp
    mv genome_feature_tables temp/.
    mv sequences temp/.
done
