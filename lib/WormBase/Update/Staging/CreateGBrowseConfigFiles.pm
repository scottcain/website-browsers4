package WormBase::Update::Staging::CreateGBrowseConfigFiles;

use Moose;
use IO::File;
use DBI;
use WormBase::FeatureFile;
use Data::Dumper;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'create GBrowse configuration files based on the content of GFF files',
    );

has 'path' => (
    is  => 'rw',
    );

has 'core_config_file' => (
    is => 'ro',
    default => 'wormbase_core.conf',
    );

has 'config_destination' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_config_destination {
    my $self = shift;
    my $release = $self->release;
    my $path  = join("/",$self->path,'releases',$release);
    $self->_make_dir($path);
    return $path;
}


has 'includes_directory' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_includes_directory {
    my $self = shift;
    my $path = $self->path;
    return "$path/includes";
}

has 'species_includes_directory' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_species_includes_directory {
    my $self = shift;
    my $path = $self->path;
    return "$path/includes-species_specific";
}




has 'f2c' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_f2c {
    my $self = shift;
    # Keys are "type:source".
    # ONLY primary features are included.

    # If you change the name of a track, also:
    #   a. update the name of the include file to match the track name
    #   b. update the include directive below.
    #   c. update the corresponding species includes file
    #
    # The name of the includes file is used to programmatically fetch some
    # information about the track (such as the "key" name).

    my $f2c = { };

    ################################################
    #
    # Category: Genes
    #
    ################################################
	
    # ALL genes
    $f2c->{'gene:WormBase'} = { 
	# Terrible name. Sorry, legacy for now, will fix with WS241:
	# 1. update here
	# 2. change name of include file
	# 3. update app
	include => 'primary_gene_track',
	children   => [ 'mRNA:WormBase',
			'five_prime_UTR:WormBase',
			'three_prime_UTR:WormBase',
                        'gene:WormBase_imported',
			'mRNA:WormBase_imported',                                 
			'five_prime_UTR:WormBase_imported',
			'three_prime_UTR:WormBase_imported' ],
	# These features are part of both WormBase:gene (all genes) and protein coding genes.
	# We use them as the top level feature for protein coding genes (and to trigger insertion of the DNA/CODING_SEGMENTS tracks)
	# 'WormBase_imported:CDS',
	# 'WormBase:CDS',
    };
    
    $f2c->{'ncRNA:WormBase'} = { 
	children   => [ 'miRNA:WormBase',
			'rRNA:WormBase', 
			'scRNA:WormBase',
			'snRNA:WormBase',
			'snoRNA:WormBase',
			'tRNA:WormBase',
			'exon:WormBase',
			'intron:WormBase'
	    ],
			    include => 'genes_noncoding',
    };

    $f2c->{'pseudogenic_transcript:WormBase'} = { 
	include    => 'genes_pseudogenes',
    };

    $f2c->{'CDS:WormBase'} = {
	children   => ['CDS:WormBase_imported'],
	include    => 'genes_protein_coding',
    };

    $f2c->{'gene:interpolated_pmap_position'} = { 
	children   => [ qw/gene:absolute_pmap_position/ ],
	include    => 'genetic_limits',
    };
    
    $f2c->{'CDS:Genefinder'} = {
	include    => 'prediction_genefinder'
    };
    
    $f2c->{'CDS:GeneMarkHMM'} = {
	include    => 'prediction_genemarkhmm',
    };			 
    
    $f2c->{'CDS:Jigsaw'} = {
	include    => 'prediction_jigsaw',
    };

    $f2c->{'CDS:mGene'} = {
	include    => 'prediction_mgene',
    };

    $f2c->{'CDS:mSplicer_orf'} = {
	include    => 'prediction_msplicer_orf',
    };

    $f2c->{'CDS:mSplicer_transcript'} = {
	include    => 'prediction_msplicer_transcript',
    };

    $f2c->{'twinscan:CDS'} = {
	include    => 'prediction_twinscan',
    };

    $f2c->{'ncRNA:RNAz'} = {
	include    => 'prediction_rnaz',
    };
	
    $f2c->{'transposable_element:Transposon'} = { 
	include    => 'transposons',
    };
	
    $f2c->{'transposable_element_CDS:WormBase_transposon'} = { 
	children   => qw[/transposable_element_Pseudogene:WormBase_transposon/],
	include    => 'transposon_genes',
    };
	
    $f2c->{'operon:operon'} = {
	include    => 'operons',
    };

    $f2c->{'operon:deprecated_operon'} = {
	include    => 'operons_deprecated',
    };
	
    $f2c->{'polyA_signal_sequence:polyA_signal_sequence'} = {
	children   => ['polyA_site:polyA_site'],
	include    => 'polya_sites',
    };
	       
    $f2c->{'SL1_acceptor_site:SL1'} = {
	children   => ['SL2_acceptor_site:SL2'],
	include    => 'trans_spliced_acceptor',
    };
	
    # This should pick up all history entries
    $f2c->{'exon:history'} = {
	children   => ['pseudogenic_transcript:history',
		       'transposable_element:history',
		       'protein_coding_primary_transcript:history',
		       'primary_transcript:history',
		       'nc_primary_transcript:history'],
	include   => 'historical_genes'
    };

    
    ################################################
    #
    # Category: Variations
    #
    ################################################
    $f2c->{'substitution:Allele'} = {
	children   => ['deletion:Allele',
		       'insertion_site:Allele',
		       'substitution:Allele',
		       'complex_substitution:Allele',
		       'transposable_element_insertion_site:Allele'],
	include => 'variations_classical_alleles',
    };
		
    $f2c->{'deletion:KO_consortium'} = {
	children   => ['deletion:CGH_allele',
		       'complex_substitution:KO_consortium',
		       'deletion:KO_consortium',
		       'point_mutation:KO_consortium',
		       'deletion:Variation_project',
		       'insertion_site:Variation_project',
		       'point_mutation:Variation_project',
		       'complex_substitution:NBP_knockout',
		       'deletion:NBP_knockout',
		       'transposable_element_insertion_site:NemaGENETAG_consortium', ],
	include => 'variations_high_throughput_alleles',
    };
    
    $f2c->{'deletion:PCoF_Allele'} = {
	children   => ['complex_substitution:PCoF_Allele',
		       'deletion:PCoF_Allele',
		       'insertion_site:PCoF_Allele',
		       'substitution:PCoF_Allele',
		       'transposable_element_insertion_site:PCoF_Allele',
		       'deletion:PCoF_CGH_allele',
		       'complex_substitution:PCoF_KO_consortium',
		       'deletion:PCoF_KO_consortium',
		       'point_mutation:PCoF_KO_consortium',
		       'point_mutation:PCoF_Million_mutation',
		       'deletion:PCoF_Million_mutation',
		       'insertion_site:PCoF_Million_mutation',
		       'complex_substitution:PCoF_Million_mutation',
		       'sequence_alteration:PCoF_Million_mutation',
		       'deletion:PCoF_Variation_project',
		       'point_mutation:PCoF_Variation_project',
		       'complex_substitution:PCoF_NBP_knockout',
		       'deletion:PCoF_NBP_knockout',
		       'transposable_element_insertion_site:PCoF_NemaGENETAG_consortium'],
	include => 'variations_change_of_function_alleles',
    };

    $f2c->{'substitution:Variation_project_Polymorhpism'} = {
	children   => ['deletion:CGH_allele_Polymorhpism',
		       'substitution:Variation_project_Polymorhpism',
		       'deletion:Variation_project_Polymorhpism',
		       'SNP:Variation_project_Polymorhpism',
		       'insertion_site:Variation_project_Polymorhpism',
		       'complex_substitution:Variation_project_Polymorhpism',
		       'sequence_alteration:Variation_project_Polymorhpism',
		       'deletion:Allele_Polymorhpism'],
	include => 'variations_polymorphisms',
    };
    
    $f2c->{'deletion:PCoF_Variation_project_Polymorhpism'} = {
	children   => ['deletion:PCoF_CGH_allele_Polymorhpism',
		       'deletion:PCoF_Variation_project_Polymorhpism',
		       'insertion_site:PCoF_Variation_project_Polymorhpism',
		       'SNP:PCoF_Variation_project_Polymorhpism',
		       'substitution:PCoF_Variation_project_Polymorhpism',
		       'complex_substitution:PCoF_Variation_project_Polymorhpism',
		       'sequence_alteration:PCoF_Variation_project_Polymorhpism'],
	include  => 'variations_change_of_function_polymorphisms',
    };

    $f2c->{'transposable_element_insertion_site:Allele'} = {
	children   => ['transposable_element_insertion_site:Mos_insertion_allele',
		       'transposable_element_insertion_site:NemaGENETAG_consortium'],
	include    => 'variations_transposon_insertion_sites',
    };

    $f2c->{'point_mutation:Million_mutation'} = {
	children   => ['point_mutation:Million_mutation',
		       'complex_substitution:Million_mutation',
		       'deletion:Million_mutation',
		       'insertion_site:Million_mutation',
		       'sequence_alteration:Million_mutation'],
	include => 'variations_million_mutation_project',
    };

    
    $f2c->{'RNAi_reagent:RNAi_primary'} = {
	children   => ['experimental_result_region:cDNA_for_RNAi'],
	include    => 'variations_rnai_best',
    };

    $f2c->{'RNAi_reagent:RNAi_secondary'} = { 
	include    => 'variations_rnai_other',
    };
		
    ################################################
    #
    # Category: SEQUENCE FEATURES
    #
    ################################################
    
    #
    # Subcategory: Binding Sites
    #

    $f2c->{'binding_site:binding_site'} = {
	include    => 'binding_sites_curated',
    };

    $f2c->{'binding_site:PicTar'} = {
	children   => ['binding_site:PicTar',
		       'binding_site:miRanda',
		       'binding_site:cisRed'],
	include => 'binding_sites_predicted',
    };
    
    $f2c->{'binding_site:binding_site_region'} = {
	include    => 'binding_regions',
    };


    $f2c->{'histone_binding_site:histone_binding_site_region'} = {
	include    => 'histone_binding_sites',
    };
	       
    $f2c->{'promoter:promoter'} = {
	include => 'promoter_regions',
    };

    $f2c->{'regulatory_region:regulatory_region'} = {
	include  => 'regulatory_regions',
    };

    $f2c->{'TF_binding_site:TF_binding_site'} = {
	include => 'transcription_factor_binding_site',
    };

    $f2c->{'TF_binding_site:TF_binding_site_region'} = {
	include => 'transcription_factor_binding_region',
    };

    #
    # Subcategory: Motifs
    #

    $f2c->{'DNAseI_hypersensitive_site:DNAseI_hypersensitive_site'} = {
	include => 'dnaseI_hypersensitive_site',
    };

    $f2c->{'G_quartet:pmid18538569'} = {
	include => 'g4_motif',
    };

    #
    # Subcategory: Translated Features
    #

    $f2c->{'sequence_motif:translated_feature'} = {
	include    => 'protein_motifs',
    };
    
    $f2c->{'translated_nucleotide_match:mass_spec_genome'} = {
	include => 'mass_spec_peptides',
    };

    #
    # Category: Expression
    #

    $f2c->{'SAGE_tag:SAGE_tag'} = {		  
	include => 'sage_tags',
    };

    
    $f2c->{'experimental_result_region:Expr_profile'} = {
	include => 'expression_chip_profiles',
    };

    $f2c->{'reagent:Expr_pattern'} = {
	include => 'expression_patterns',
    };

    $f2c->{'transcript_region:RNASeq_reads'} = {
	include => 'rnaseq',
    };

    $f2c->{'intron:RNASeq_splice'} = {
	include => 'rnaseq_splice',
    };

    $f2c->{'transcript_region:RNASeq_F_asymmetry'} = {
	include => 'rnaseq_asymmetries',
	children   => ['transcript_region:RNASeq_R_asymmetry'],
    };

    $f2c->{'mRNA_region:Polysome_profiling'} = {
	include => 'polysomes',
    };

    ################################################
    #
    # Category: Genome structure
    #
    ################################################
    
    #
    # Subcategory: Assembly & Curation
    #

    $f2c->{'deletion:Somatic_diminution'} = {
	include  => 'somatic_diminutions',
    };

    $f2c->{'nucleotide_match:EXONERATE_BAC_END_BEST'} = {
	children => ['nucleotide_match:EXONERATE_BAC_END_OTHER'],
	include  => 'bac_ends',
    };

    $f2c->{'possible_base_call_error:RNASeq'} = {
	include => 'genome_sequence_errors',
    };

    $f2c->{'base_call_error_correction:RNASeq'} = {
	include => 'genome_sequence_errors_corrected'
    };

    $f2c->{'assembly_component:Link'} = {
	children   => ['assembly_component:Genomic_canonical'],
	include    => 'links_and_superlinks',
    };	

    $f2c->{'assembly_component:Genbank'} = {
	include => 'genbank_entries',
    };

    $f2c->{'assembly_component:Genomic_canonical'} = {
	include => 'genomic_canonical',
    };

    $f2c->{'duplication:segmental_duplication'} = {
	include => 'segmental_duplications',
    };
    
    #
    # Subcategory: Repeats
    #
    
    $f2c->{'low_complexity_region:dust'} = {
	include => 'repeats_dust',
    };
    
    $f2c->{'repeat_region:RepeatMasker'} = {
	include => 'repeats_repeat_masker',
    };

    $f2c->{'inverted_repeat:inverted'} = {
	include => 'repeats_tandem_and_inverted',
	children   => ['tandem_repeat:tandem'],
    };

    ################################################
    #
    # Category: Transcription
    #
    ################################################

    $f2c->{'expressed_sequence_match:BLAT_EST_BEST'} = {
	include => 'est_best'
    };

    $f2c->{'expressed_sequence_match:BLAT_EST_OTHER'} = {
	include => 'est_other'
    };

    $f2c->{'expressed_sequence_match:BLAT_mRNA_BEST'} = {
	include => 'mrna_best',
	children   => ['expressed_sequence_match:BLAT_ncRNA_BEST'],
    };

    $f2c->{'expressed_sequence_match:BLAT_ncRNA_OTHER'} = {
	include => 'mrna_other',
	children => ['expressed_sequence_match:BLAT_mRNA_OTHER'],
    };

    $f2c->{'TSS:RNASeq'} = {
	include => 'transcription_start_site',
    };

    $f2c->{'transcription_end_site:RNASeq'} = {
	include => 'transcription_end_site',
    };

    $f2c->{'nucleotide_match:TEC_RED'} = {
	include => 'tecred_tags',
    };

    $f2c->{'five_prime_open_reading_frame:micro_ORF'} = {
	include => 'micro_orf',
    };

    $f2c->{'PCR_product:Orfeome'} = {
	include => 'orfeome_pcr_products',
    };

    $f2c->{'transcribed_fragment:TranscriptionallyActiveRegion'} = {
	include => 'transcriptionally_active_region',
    };

    $f2c->{'expressed_sequence_match:BLAT_OST_BEST'} = {
	includes => 'orfeome_sequence_tags',
    };

    $f2c->{'expressed_sequence_match:BLAT_RST_BEST'} = {
	include => 'race_sequence_tags',
    };

    ################################################
    #
    # Category: Sequence similarity
    #
    ################################################
    
    $f2c = $self->_create_nucleotide_similarity_stanzas($f2c);
    
    $f2c->{'protein_match:UniProt-BLASTX'} = {
	include => 'sequence_similarity_uniprot_blastx',
    };
   
    $f2c->{'expressed_sequence_match:BLAT_Caen_EST_BEST'} = {
	children => ['expressed_sequence_match:BLAT_Caen_mRNA_BEST'],
	include => 'sequence_similarity_wormbase_core_ests_and_mrnas_best',
    };
    
    $f2c->{'expressed_sequence_match:BLAT_Caen_EST_OTHER'} = {
	children => ['expressed_sequence_match:BLAT_Caen_mRNA_OTHER'],
	include => 'sequence_similarity_wormbase_core_ests_and_mrnas_other',
    };

    $f2c->{'expressed_sequence_match:NEMBASE_cDNAs-BLAT'} = {
	include => 'sequence_similarity_nembase_cdnas',
    };
    
    $f2c->{'expressed_sequence_match:EMBL_nematode_cDNAs-BLAT'} = {
	include => 'sequence_similarity_nematode_cdnas',
    };

    $f2c->{'expressed_sequence_match:NEMATODE.NET_cDNAs-BLAT'} = {
	include => 'sequence_similarity_nematode_net_cdnas',
    };

    $f2c->{'nucleotide_match:TIGR_BEST'} = {
	include => 'sequence_similarity_tigr_gene_models',
    };

    $f2c->{'nucleotide_match:TIGR_OTHER'} = {
	include => 'sequence_similarity_tigr_gene_models_other',
    };
    

    ################################################
    #
    # Reagents
    #
    ################################################

    $f2c->{'PCR_product:promoterome'} = {
	include => 'pcr_product_promoterome',
    };
    
    $f2c->{'reagent:Oligo_set'} = {
	include => 'microarray_oligo_probes',
    };

    $f2c->{'PCR_product:promoterome'} = {
	include => 'pcr_product_promoterome',
    };

    $f2c->{'reagent:Oligo_set'} = {
	include => 'microarray_oligo_probes',
    };


    # This will require special handling - we've already seen this feature
    # before
    $f2c->{'PCR_product'} = {
	include => 'pcr_products',
    };

    # This might ALSO require special handling: overlaps with other tracks
    $f2c->{'region:Vancouver_fosmid'} = {
	children=> [qw/assembly_component:Genomic_canonical/],
	include => 'clones',
    };


    return $f2c;
}





sub run {
    my $self = shift;

    my ($species) = $self->wormbase_managed_species;    
    my $release = $self->release;

    my $features = { };
    foreach my $name (sort { $a cmp $b } @$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
#	next unless $name =~ /elegans/;
	$self->log->info(uc($name). ': start');	

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {

	    my $id = $bioproject->bioproject_id;
	    my $gff= $bioproject->gff_file;       # this includes the full path.
	    
	    $features->{species}->{"${name}_$id"}->{gff_version} = '3';
	    $features->{species}->{"${name}_$id"}->{file}        = $gff;
	    $features->{species}->{"${name}_$id"}->{species}     = $name;
	    $self->log->info("   Processing bioproject: $id");	    

	    open FILE, "gunzip -c $gff |" or warn $! && next;
	    while (my $line = <FILE>) {
		next if $line =~ /^\#/;	
		my ($ref,$source,$method,@rest) = split(/\t/,$line);
		
		# Record features seen for each species.
		$features->{species}->{"${name}_$id"}->{features}->{"$method:$source"}++;	
		
		# ... and also in aggregate across all species.
		$features->{global}->{"$method:$source"}++;
	    }
	    close FILE;
	}	
	$self->log->info(uc($name). ': done'); 
    }
    $self->generate_config($features);
    $self->print_global_stats($features);
}



sub symlink {
    my ($self,$species) = @_;

    my $release = $self->release;
    
    my $path = $self->path;
    my $config_destination = $self->config_destination;
    
    chdir($path);
    $self->update_symlink({target  => "releases/$release/$species.conf",
			   symlink => "$species.conf"
			  });
    return;
}



sub generate_config {
    my ($self,$features) = @_;

    my $release = $self->release;
    my $f2c = $self->f2c();
    
    foreach my $species ( sort keys %{$features->{species}} ) {

	# Get the core config.
	my $base_config = WormBase::FeatureFile->new(-file => join('/',$self->path,$self->core_config_file));
	
	my $fh  = IO::File->new("> " . $self->config_destination . "/$species.stats")
	    or $self->log->logdie("Couldn't open the species stats file: $!");
	
	print $fh "gff_version: " . $features->{species}->{$species}->{gff_version} . "\n"; 
	print $fh "file: " . $features->{species}->{$species}->{file} . "\n";
	print $fh join("\t",qw/feature children source method track count/) . "\n";

	foreach my $feature (sort { $a cmp $b } keys %{$features->{species}->{$species}->{features}}) {

	    # Is there a suitable include for this feature?
	    my $include = $f2c->{$feature}->{include};

	    my ($method,$source) = split(":",$feature);
	           
	    if ($include) {

		# This species has a feature that requires a new stanza. Merge it into the main config
		$base_config = $self->merge_to_base_config($base_config,
							   join('/',$self->includes_directory,$include. '.track'));
				
		# Get the key (as a human readable name) for this track.
		my $key = $base_config->setting(uc($include),'key');
		unless ($key) {
		    warn "I couldnt find a key for $include !!!\n\n";
		}

		# Record stats on a per-species basis.
		print $fh join("\t",
			       $feature,
			       "",
			       $source,
			       $method,
			       "$key ($include)",
			       $features->{species}->{$species}->{features}->{$feature}
		    )
		    . "\n"; 	       

		# Record that we have config for this feature.
		$features->{$feature}->{config} = "$key ($include)";

		# Iterate through children of this feature (if there are any)
		# I do this simply to create a nice accounting of features.
		# (I could also fetch these through the config although not all children are listed)
		my @children = eval { @{$f2c->{$feature}->{children}} };
		foreach my $child (@children) {
		    next if $child eq $feature;  # may have already seen.
		    my ($child_method,$child_source) = split(":",$child);
		    my $count =  $features->{species}->{$species}->{features}->{$child};
		    $count ||= 0;
		    print $fh join("\t",
				   "",
				   $child,					     
				   $child_source,
				   $child_method,
				   "$key ($include)",
				   $count,
			) . "\n"; 		   
		    $features->{$child}->{config} = "$key ($include)";
		}
	    } else { 		
		# No config found. We are either 
		#   a) a child/sibling/non-primary feature that will be picked up later or
		#   b) a parent feature for which no configuration exists. We should take note of these.
		next;
	    }	    	   
	}
	undef $fh;

	# Is there an overrides file for this species?
	# This file will also contain any other extra stanzas that we may need.
	my $species_overrides = join('/',$self->species_includes_directory,$species) . '.conf';
	if ( -e $species_overrides) {
	    # This species has a feature that requires a new stanza. Merge it into the main config
	    $base_config = $self->merge_to_base_config($base_config,$species_overrides);
	}
	
	# Build the database stanza for this species. We do it programmatically
	# to include the release number then merge to the base_config.
	my $db_stanza = $self->_create_database_stanza($species);
	$base_config = $self->merge_to_base_config($base_config,$db_stanza);

	$self->dump_configuration($species,$base_config);
	$self->symlink($species);
    }
}





sub merge_to_base_config {
    my ($self,$base_config,$incoming_config) = @_;
    
    my $new_config;
    # Is this an external file or a stanza we have built
    if ($incoming_config =~ /[conf|track]$/) {
	$new_config = WormBase::FeatureFile->new(-file => $incoming_config);
    } else {
	$new_config = WormBase::FeatureFile->new(-text => $incoming_config);
    }
    foreach my $stanza ($new_config->setting()) {
	foreach my $option ($new_config->setting($stanza)) {
	    my $value = $new_config->setting($stanza => $option);
	    $base_config->set($stanza,$option => $value);
	}
    }
    return $base_config;
}    


# Dump the complete config to a new file.
sub dump_configuration {
    my ($self,$species,$config) = @_;
#    print Dumper($config);
    
    my $fh = IO::File->new("> " . $self->config_destination . "/$species.conf") 
	or $self->log->logdie("Couldn't open the species config file: $!");
    
    print $fh <<END
#####################################################
#
# NOTE! This configuration file was programmatically
# generated.  You can edit this in-place for testing
# purposes but all changes will
# need to be moved to CreateGBrowseConfigFiles.pm
#
#####################################################
END
;

    my @stanzas = $config->setting();
    foreach my $stanza (sort { $a cmp $b } @stanzas) {
	print $fh "[$stanza]\n";
	foreach my $option ($config->setting($stanza)) {	   
	    my $value = $config->setting($stanza => $option);
	    print $fh "$option = " . $value . "\n";
	}
	print $fh "\n\n";
    }
    undef $fh;
}


sub print_global_stats {
    my ($self,$features) = @_;

    my $fh  = IO::File->new("> " . $self->config_destination . "/ALL_SPECIES.stats") 
	or $self->log->logdie("Couldn't open the global stats file");
    
    # Generate a table of ALL species with feature counts
    print $fh join("\t",'FEATURE','SOURCE','TYPE','TRACK',sort keys %{$features->{species}}),"\n";
    foreach my $feature (sort {$a cmp $b } keys %{$features->{global}}) {
	my @values;
	push @values,$feature;
	my ($method,$source) = split(":",$feature);
	push @values,$source,$method;

	if (my $track = eval { $features->{$feature}->{config} }) {
	    push @values,$track;
	} else {
	    push @values, 'NO CONFIG AVAILABLE';
	}
	
	foreach my $species ( sort keys %{$features->{species}} ) {
	    my $val = $features->{species}->{$species}->{features}->{$feature};
	    $val ||= 0;       
	    push @values,$val;
	}
	print $fh join("\t",@values);
	print $fh "\n";
    }

    undef $fh;
}


# Programmatically create the database stanza
# for this species.
sub _create_database_stanza {
    my ($self,$species) = @_;
    my $release = $self->release;

    my $stanza = <<END;
[this_database:database]
db_adaptor  = Bio::DB::SeqFeature::Store
db_args     = -adaptor DBI::mysql
              -dsn dbi:mysql:database=${species}_${release};host=mysql.wormbase.org
	      -user wormbase
	      -pass sea3l3ganz
search options = default, +wildcard, -stem, +fulltext, +autocomplete
END
    return $stanza;
}





# This should probably just generate the configuration as well.
sub _create_nucleotide_similarity_stanzas {
    my ($self,$data) = @_;
    
    foreach (qw/bmalayi
                cbrenneri
                cbriggsae 
                celegans
                cjaponica 
                cremanei
                ppacificus
                dmelanogaster
                hsapiens
                scerevisiae
              / ) {

	$data->{"protein_match:${_}_proteins-BLASTX"} = {
	    include => "sequence_similarity_${_}_proteins_blastx",
	};

	$data->{"expressed_sequence_match:${_}_ESTs-BLAT"} = {
	    include => "sequence_similarity_${_}_ests",
	};
	
	$data->{"expressed_sequence_match:${_}_mRNAs-BLAT"} = {
	    include => "sequence_similarity_${_}_mrnas",
	};

	$data->{"expressed_sequence_match:${_}_OSTs-BLAT"} = {
	    include => "sequence_similarity_${_}_osts",
	};

	$data->{"expressed_sequence_match:${_}_RSTs-BLAT"} = {
	    include => "sequence_similarity_${_}_rsts",
	};
    }
    return $data;
}




1;

