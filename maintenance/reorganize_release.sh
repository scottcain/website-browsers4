#!/bin/bash

# Simple script to reorganize the WormBase FTP sites.

# Root of the FTP site.
# Adjust as appropriate.
FTP_ROOT=/usr/local/ftp/pub/wormbase

# Shouldn't need to adjust anything below here.

# Not all species for every release. Will need to check or purge later.
SPECIES=("
	b_malayi
        c_angaria
	c_briggsae
	c_brenneri
	c_elegans
	c_japonica
	c_remanei
	h_bacteriophora
	h_contortus
	m_hapla
	m_incognita
	p_pacificus
        t_spiralis
	")


###################################
# Reoragnize WS110 - WS190 first
# so they match the input for
# subsequent steps.
###################################

REORG_FROZEN_RELEASES=0

if [ $REORG_FROZEN_RELEASES ]
then
    exit
    
    for ((RELEASE=77 ; RELEASE <= 190 ; RELEASE++))
    do
	
	if [ -d "${FTP_ROOT}/releases/WS${RELEASE}" ]
	then
	    
	    echo "Processing release $RELEASE..."
	    cd ${FTP_ROOT}/releases/
	    chmod 2775 WS${RELEASE}
	    cd ${FTP_ROOT}/releases/WS${RELEASE}
	    
	    echo "   fixing permissions..."
	    chmod 2775 CHROMOSOMES
	    chmod 664 CHROMOSOMES/*
	    chmod 2775 CHROMOSOMES/SUPPLEMENTARY_GFF
	    chmod 644 CHROMOSOMES/SUPPLEMENTARY_GFF/*
	    chmod 664 *.gz letter* wormpep* wormrna* INSTALL models* database* md5* INSTALL*
	    
	    echo "   creating directories..."
	    mkdir -p acedb
	    mkdir -p genomes/c_elegans/genome_feature_tables/GFF2
	    mkdir -p genomes/c_elegans/sequences/dna
	    mkdir -p genomes/c_elegans/sequences/protein
	    mkdir -p genomes/c_elegans/sequences/rna
	    mkdir assembly
	    
	    echo "   stashing acedb components..."
	    cp database* models* md5* INSTALL acedb/.
	    
	    echo "   stashing assembly information..."
	    cp CHROMOSOMES/*.agp assembly/.
	    
        # Create concatenated gff and dna files
	    echo "   creating concatenated GFF file..."
            gzip CHROMOSOMES/*.gff
            gzip CHROMOSOMES/*.dna.fa
	    gzip CHROMOSOMES/SUPPLEMENTARY_GFF/*.gff
            cat CHROMOSOMES/*.gff.gz > genomes/c_elegans/genome_feature_tables/GFF2/c_elegans.WS${RELEASE}.gff.gz
	    cat CHROMOSOMES/SUPPLEMENTARY_GFF/*.gff.gz >> genomes/c_elegans/genome_feature_tables/GFF2/c_elegans.WS${RELEASE}.gff.gz
	    
	    
	    echo "   creating concatenated genomic DNA file..."
	    cat CHROMOSOMES/CHROMOSOME*masked* > genomes/c_elegans/sequences/dna/c_elegans_masked.WS${RELEASE}.dna.fa.gz
	    rm -rf CHROMOSOMES/CHROMOSOME*masked*        
            cat CHROMOSOMES/CHROMOSOME*.dna.gz > genomes/c_elegans/sequences/dna/c_elegans.WS${RELEASE}.dna.fa.gz
	    
        # Save intergenic, wormpep, and wormrna
	    echo "   saving intergenic, wormpep, and wormrna files..."        
            cp CHROMOSOMES/intergenic* genomes/c_elegans/sequences/dna/.
            cp wormpep* genomes/c_elegans/sequences/protein/.
            cp wormrna* genomes/c_elegans/sequences/rna/.
	    
	    echo "   storing unneeded files for easy trashing..."
            mkdir confirm_before_trashing
            mv files_in_tar wormpep* wormrna* database* models* md5* INSTALL* CHROMOSOMES confirm_before_trashing/.
	    echo "Done."
	fi
    done
fi

########################################
# Special clean up for WS77 - WS190.
########################################

# WS110
cd ${FTP_ROOT}/releases/WS110
mkdir -p genomes/c_briggsae/sequences/protein
cp brigpep2 genomes/c_briggsae/sequences/protein/brigpep110
gzip genomes/c_briggsae/sequences/protein/brigpep110
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.
mv brigpep2 confirm_before_trashing/.

# WS120
cd ${FTP_ROOT}/releases/WS120
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.

# WS130
cd ${FTP_ROOT}/releases/WS130
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.

# WS140
cd ${FTP_ROOT}/releases/WS140
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.
# Stash WS140a into WS140
cd ${FTP_ROOT}/releases/WS140/acedb
mkdir WS140a
mv database*140a* WS140a/.
mkdir WS140
mv ${FTP_ROOT}/releases/WS140a/database* WS140/.
rm -rf ${FTP_ROOT}/releases/WS140a

# WS150
cd ${FTP_ROOT}/releases/WS150
# Remove symbolic link
rm WS150
# Gzip ace patches and remove cruft
gzip WS150_*
rm -rf phenotype_remark_patch.ace
mv *.ace.gz acedb/.
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.

# WS160
cd ${FTP_ROOT}/releases/WS160
# Remove database cruft
chmod 2775 database
rm -rf database/
rm -rf md5sum.160
# Gzip ace patches and remove cruft
gzip *ace
mv *.ace.gz acedb/.
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.


# WS170
cd ${FTP_ROOT}/releases/WS170
# Remove database cruft
rm -rf md5sum.170
# Gzip ace patches and remove cruft
gzip *ace
mv *.ace.gz acedb/.
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
mv best_blastp* confirm_before_trashing/.
mv brigpep* genomes/c_briggsae/sequences/protein
mv brig*gz confirm_before_trashing/.
bunzip2 brigdna170.bz2
mv brigdna170 genomes/c_briggsae/sequences/dna/c_briggsae.WS170.dna.fa
gzip genomes/c_briggsae/sequences/dna/*.fa
chmod 2775 confirm_before_trashing/CHROMOSOMES/briggff170
gzip confirm_before_trashing/CHROMOSOMES/briggff170/*.gff
mkdir -p genomes/c_briggsae/genome_feature_tables/GFF2
cat confirm_before_trashing/CHROMOSOMES/briggff170/*.gff.gz > genomes/c_briggsae/genome_feature_tables/GFF2/c_briggsae.WS170.gff.gz




# WS180
cd ${FTP_ROOT}/releases/WS180
mkdir -p genomes/c_briggsae/sequences/protein
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
cp best_blastp* confirm_before_trashing/.
mv brigpep* genomes/c_briggsae/sequences/protein
mkdir -p genomes/c_briggsae/sequences/rna
cp brigrna* genomes/c_briggsae/sequences/rna
mv brig*gz confirm_before_trashing/.
chmod 2775 confirm_before_trashing/CHROMOSOMES/briggff180
gzip confirm_before_trashing/CHROMOSOMES/briggff180/*.gff
gzip confirm_before_trashing/CHROMOSOMES/briggff180/*.dna
mkdir -p genomes/c_briggsae/genome_feature_tables/GFF2
cat confirm_before_trashing/CHROMOSOMES/briggff180/*.gff.gz > genomes/c_briggsae/genome_feature_tables/GFF2/c_briggsae.WS180.gff.gz
cat confirm_before_trashing/CHROMOSOMES/briggff180/*.dna.gz > genomes/c_briggsae/sequences/dna/c_briggsae.WS180.dna.fa.gz


# WS190
cd ${FTP_ROOT}/releases/WS190
mkdir -p genomes/c_briggsae/sequences/protein
mv patch-files acedb/.
cp best_blastp_hits.*.gz genomes/c_elegans/sequences/protein/.
cp best_blastp_hits_brig* genomes/c_briggsae/sequences/protein/.
cp best_blastp* confirm_before_trashing/.
mv brigpep* genomes/c_briggsae/sequences/protein
mkdir -p genomes/c_briggsae/sequences/rna
cp brigrna* genomes/c_briggsae/sequences/rna
mv brig*gz confirm_before_trashing/.
chmod 2775 confirm_before_trashing/CHROMOSOMES/briggff190
gzip confirm_before_trashing/CHROMOSOMES/briggff190/*.gff
gzip confirm_before_trashing/CHROMOSOMES/briggff190/*.dna
mkdir -p genomes/c_briggsae/genome_feature_tables/GFF2
cat confirm_before_trashing/CHROMOSOMES/briggff190/*.gff.gz > genomes/c_briggsae/genome_feature_tables/GFF2/c_briggsae.WS190.gff.gz
cat confirm_before_trashing/CHROMOSOMES/briggff190/*.dna.gz > genomes/c_briggsae/sequences/dna/c_briggsae.WS190.dna.fa.gz
mkdir -p genomes/c_remanei/sequences/protein
mkdir -p genomes/c_remanei/sequences/dna
mkdir -p genomes/c_remanei/sequences/rna
mkdir -p genomes/c_remanei/genome_feature_tables/GFF2
cp best_blastp_hits_rem* genomes/c_remanei/sequences/protein/.
cp remapep* genomes/c_remanei/sequences/protein/.
mv rema* confirm_before_trashing/.
mv *ace.gz acedb/.
chmod 2775 remagff190
gzip remagff190/*
mv confirm_before_trashing/CHROMOSOMES/remagff190/remanei.gff.gz genomes/c_remanei/genome_feature_tables/GFF2/c_remanei.WS190.gff.gz
mv confirm_before_trashing/CHROMOSOMES/remagff190/remanei.dna.gz genomes/c_remanei/sequences/dna/c_remanei.WS190.dna.fa.gz


fi


#############################
# Reoragnize WS100 - WS225
#############################

for ((RELEASE=100; RELEASE <= 225 ; RELEASE++))
do

    if [ -d "${FTP_ROOT}/releases/WS${RELEASE}" ]
    then
	
	echo "Processing release: $RELEASE..."
	cd ${FTP_ROOT}/releases/WS${RELEASE}
	mkdir confirm_before_trashing
	
        # Rename the genomes directory to the more accurate "species"
	mv genomes species
	
        # Flatten the hierarchy.
	for THIS_SPECIES in ${SPECIES}
	do
	    
	    if [ -d "${FTP_ROOT}/releases/WS${RELEASE}/species/${THIS_SPECIES}" ]
	    then
		echo "   PROCESSING: ${RELEASE}:${THIS_SPECIES}"
		mkdir confirm_before_trashing
		cd species/${THIS_SPECIES}
		
            # Make sure everything is already zipped up.
		echo "   gzipping files..."
		gzip genome_feature_tables/GFF2/*.gff
		gzip genome_feature_tables/GFF2/SUPPLEMENTARY_GFF/*.gff
		gzip sequences/dna/*.dna.fa
		
            # Rename gff.gz to gff2.gz and place it in species/g_species/
		echo "   renaming *gff to ${THIS_SPECIES}.WS${RELEASE}.gff2.gz..."
		cp genome_feature_tables/GFF2/*.WS${RELEASE}.gff.gz ${THIS_SPECIES}.WS${RELEASE}.gff2.gz
		
            # Concatenate SUPPLEMENTARY_GFF to consolidated gff
		echo "   concatenating SUPPLEMENTARY_GFF to the primary gff2 file..."
		cat genome_feature_tables/GFF2/SUPPLEMENTARY_GFF/*.gff.gz >> ${THIS_SPECIES}.WS${RELEASE}.gff2.gz
		
            # relocate GFF3 (might not exist)
		echo "   relocating GFF2 file (if exists)..."
		cp genome_feature_tables/GFF3/*.WS${RELEASE}.gff3.gz ${THIS_SPECIES}.WS${RELEASE}.gff3.gz
		
            # Rename dna.fa.gz to g_species.WSXXX.genomic.fa.gz
		echo "   renaming dna file to ${THIS_SPECIES}.WS${RELEASE}.genomic.fa.gz..."
		cp sequences/dna/${THIS_SPECIES}.WS${RELEASE}.dna.fa.gz ${THIS_SPECIES}.WS${RELEASE}.genomic.fa.gz
		
            # Rename intergenic sequences to g_species.WSXXX.intergenic_sequence.fa.gz
		echo "   renaming intergenic_sequences.dna.gz to ${THIS_SPECIES}.WS${RELEASE}.intergenic_sequence.fa.gz..."
		cp sequences/dna/intergenic_sequences.dna.gz ${THIS_SPECIES}.WS${RELEASE}.intergenic_sequence.fa.gz
		
            # Rename masked and softmasked
		echo "   renaming masked sequence to ${THIS_SPECIES}.WS{$RELEASE}.genomic_masked.fa.gz..."
		cp sequences/dna/${THIS_SPECIES}_masked.WS${RELEASE}.dna.fa.gz ${THIS_SPECIES}.WS${RELEASE}.genomic_masked.fa.gz
		echo "   renaming masked sequence to ${THIS_SPECIES}.WS{$RELEASE}.genomic_softmasked.fa.gz..."
		cp sequences/dna/${THIS_SPECIES}_softmasked.WS${RELEASE}.dna.fa.gz ${THIS_SPECIES}.WS${RELEASE}.genomic_softmasked.fa.gz
		
            # Save RNA
		echo "   renaming RNA to ${THIS_SPECIES}.WS${RELEASE}.ncrna_transcripts.fa.gz..."
		cp sequences/rna/*.gz ${THIS_SPECIES}.WS${RELEASE}.ncrna_transcripts.fa.gz
		
            # Save the fasta for the *pep, and rename it following convention.
		echo "    renaming the peptide fasta to ${THIS_SPECIES}.WS${RELEASE}.protein.fa.gz..."
		cp sequences/protein/*.WS${RELEASE}.fa.gz ${THIS_SPECIES}.WS${RELEASE}.protein.fa.gz
		
            # Save the spliced sequences (distributed as part of wormpep?)
		echo "   untarring *pep and saving the cds transcript as ${THIS_SPECIES}.WS${RELEASE}.cds_transcripts.fa.gz..."
		cd sequences/protein
		tar xzf *.tar.gz
		cd ../../
		cp sequences/protein/*.dna* ${THIS_SPECIES}.WS${RELEASE}.cds_transcripts.fa.gz
		
           # Save the full wormpep package
		echo "   saving the wormpep package as ${THIS_SPECIES}.WS${RELEASE}.wormpep_package.tar.gz..."
		cp sequences/protein/*.tar.gz ${THIS_SPECIES}.WS${RELEASE}.wormpep_package.tar.gz
		
           # Save blast hits
		echo "   saving best blast hist as ${THIS_SPECIES}.WS${RELEASE}.best_blast_hits.gz..."
		cp sequences/protein/best_blast* ${THIS_SPECIES}.WS${RELEASE}.best_blast_hits.gz
		
           # The letter
		cp letter.WS${RELEASE} letter.WS${RELEASE}.txt
		
           # Keep source directories around to make sure we have what we want to retain.
		echo "   retaining files for post-reorganization confirmation..."
		mkdir confirm_before_trashing
		mv genome_feature_tables confirm_before_trashing/.
		mv letter.WS${RELEASE} sequences confirm_before_trashing/.
		echo "   DONE: ${RELEASE}: ${THIS_SPECIES}"
	    fi
	done	
    fi
    echo "DONE: ${RELEASE}";
done
