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

has 'overrides_directory' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_overrides_directory {
    my $self = shift;
    my $path = $self->path;
    return "$path/includes-species_specific";
}

sub run {
    my $self = shift;

    my ($species) = $self->wormbase_managed_species;    
    my $release = $self->release;

    my $features = { };
    foreach my $name (sort { $a cmp $b } @$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	next unless $name =~ /elegans/;
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
    my $features2config = $self->features2config();
    
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
	    my $include = $features2config->{$feature}->{include};

	    my ($method,$source) = split(":",$feature);
	           
	    if ($include) {

		# This species has a feature that requires a new stanza. Merge it into the main config
		$base_config = $self->merge_to_base_config($base_config,join('/',$self->includes_directory,$include. '.track'));
				
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
		my @children = eval { @{$features2config->{$feature}->{children}} };
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
	my $species_overrides = join('/',$self->overrides_directory,$species) . '.conf';
	if ( -e $species_overrides) {
	    # This species has a feature that requires a new stanza. Merge it into the main config
	    $base_config = $self->merge_to_base_config($base_config,$species_overrides);
	}

	$self->dump_configuration($species,$base_config);
	$self->symlink($species);
    }
}





sub merge_to_base_config {
#    my ($self,$base_config,$raw_config) = @_;
    my ($self,$base_config,$file) = @_;

    my $new_config = WormBase::FeatureFile->new(-file => $file);
#    my $new_config = WormBase::FeatureFile->new(-text => $raw_config);
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








sub features2config {
    my $self = shift;
    # Keys are "type:source".
    # ONLY primary features are included.
    # If you change the name of a track, 
    # the name of the include file below should ALSO be changed
    # and also for any species overrides files.
   
    my $features2config = { };

################################################
#
# Category: Genes
#
################################################
	
    # ALL genes
    $features2config->{'gene:WormBase'} = { 
	# Terrible name. Sorry, legacy for now, will fix later.
	include => 'primary_gene_track',
	children   => [ 'mRNA:WormBase',
			'five_prime_UTR:WormBase',
			'three_prime_UTR:WormBase',
			'mRNA:WormBase_imported',                                 
			'five_prime_UTR:WormBase_imported',
			'three_prime_UTR:WormBase_imported' ],
	# These features are part of both WormBase:gene (all genes) and protein coding genes.
	# We use them as the top level feature for protein coding genes (and to trigger insertion of the DNA/CODING_SEGMENTS tracks)
	# 'WormBase_imported:CDS',
	# 'WormBase:CDS',

    };
    
    $features2config->{'ncRNA:WormBase'} = { 
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

    $features2config->{'pseudogenic_transcript:WormBase'} = { 
	include    => 'genes_pseudogenes',
    };

    $features2config->{'CDS:WormBase'} = {
	children   => ['CDS:WormBase_imported'],
	include    => 'genes_protein_coding',
    };

    $features2config->{'gene:interpolated_pmap_position'} = { 
	children   => [ qw/gene:absolute_pmap_position/ ],
	include    => 'genetic_limits',
    };
    
    $features2config->{'CDS:Genefinder'} = {
	include    => 'prediction_genefinder'
    };
    
    $features2config->{'CDS:GeneMarkHMM'} = {
	include    => 'prediction_genemarkhmm'
    };			 
    
    $features2config->{'CDS:Jigsaw'} = {
	include    => 'prediction_jigsaw'
    };

    $features2config->{'CDS:mGene'} = {
	include    => 'prediction_mgene'
    };

    $features2config->{'CDS:mSplicer_orf'} = {
	include    => 'prediction_msplicer_orf'
    };

    $features2config->{'CDS:mSplicer_transcript'} = {
	include    => 'prediction_msplicer_transcript'
    };

    $features2config->{'twinscan:CDS'} = {
	include    => 'prediction_twinscan'
    };

    $features2config->{'ncRNA:RNAz'} = {
	include    => 'prediction_rnaz'
    };
	
    $features2config->{'transposable_element:Transposon'} = { 
	include    => 'transposons',
    };
	
    $features2config->{'transposable_element_CDS:WormBase_transposon'} = { 
	children   => qw[/transposable_element_Pseudogene:WormBase_transposon/],
	include    => 'transposon_genes',
    };
	
    $features2config->{'operon:operon'} = {
	include    => 'operons',
    };

    $features2config->{'operon:deprecated_operon'} = {
	include    => 'operons_deprecated',
    };
	
    $features2config->{'polyA_signal_sequence:polyA_signal_sequence'} = {
	children   => ['polyA_site:polyA_site'],
	include    => 'polya_sites',
    };
	       
    $features2config->{'SL1_acceptor_site:SL1'} = {
	children   => ['SL2_acceptor_site:SL2'],
	include    => 'trans_spliced_acceptor',
    };
	
    # This should pick up all history entries
    $features2config->{'exon:history'} = {
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
    $features2config->{'substitution:Allele'} = {
	children   => ['deletion:Allele',
		       'insertion_site:Allele',
		       'substitution:Allele',
		       'complex_substitution:Allele',
		       'transposable_element_insertion_site:Allele'],
	include => 'variations_classical_alleles',
    };
		
    $features2config->{'deletion:KO_consortium'} = {
	children   => ['deletion:CGH_allele',
		       'complex_substitution:KO_consortium',
		       'deletion:KO_consortium',
		       'point_mutation:KO_consortium',
		       'deletion:Variation_project',
		       'insertion_site:Variation_project',
		       'point_mutation:Variation_project',
		       'complex_substitution:NBP_knockout',
		       'deletion:NBP_knockout',
		       'transposable_element_insertion_site:NemaGENETAG_consortium'
	    ],
			   include => 'variations_high_throughput_alleles',
    };

    $features2config->{'deletion:PCoF_Allele'} = {
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

    $features2config->{'substitution:Variation_project_Polymorhpism'} = {
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
    
    $features2config->{'deletion:PCoF_Variation_project_Polymorhpism'} = {
	children   => ['deletion:PCoF_CGH_allele_Polymorhpism',
		       'deletion:PCoF_Variation_project_Polymorhpism',
		       'insertion_site:PCoF_Variation_project_Polymorhpism',
		       'SNP:PCoF_Variation_project_Polymorhpism',
		       'substitution:PCoF_Variation_project_Polymorhpism',
		       'complex_substitution:PCoF_Variation_project_Polymorhpism',
		       'sequence_alteration:PCoF_Variation_project_Polymorhpism'],
	include  => 'variations_change_of_function_polymorphisms',
    };

    $features2config->{'transposable_element_insertion_site:Allele'} = {
	children   => ['transposable_element_insertion_site:Mos_insertion_allele',
		       'transposable_element_insertion_site:NemaGENETAG_consortium'],
	include    => 'variations_transposon_insertion_sites',
    };

    $features2config->{'point_mutation:Million_mutation'} = {
	children   => ['point_mutation:Million_mutation',
		       'complex_substitution:Million_mutation',
		       'deletion:Million_mutation',
		       'insertion_site:Million_mutation',
		       'sequence_alteration:Million_mutation'],
	include => 'variations_million_mutation_project',
    };

    
    $features2config->{'RNAi_reagent:RNAi_primary'} = {
	children   => ['experimental_result_region:cDNA_for_RNAi'],
	include    => 'variations_rnai_best',
    };

    $features2config->{'RNAi_reagent:RNAi_secondary'} = { 
	include    => 'variations_rnai_other',
    };
		
################################################
#
# Category: SEQUENCE FEATURES
#
################################################
    
    
################################################
#
# Subcategory: Binding Sites
#
################################################    

    $features2config->{'binding_site:binding_site'} = {
	include    => 'binding_sites_curated',
    };

    $features2config->{'binding_site:PicTar'} = {
	children   => ['binding_site:PicTar',
		       'binding_site:miRanda',
		       'binding_site:cisRed'],
	include => 'binding_sites_predicted',
    };
    
    $features2config->{'binding_site:binding_site_region'} = {
	include    => 'binding_regions',
    };


    $features2config->{'histone_binding_site:histone_binding_site_region'} = {
	include    => 'histone_binding_sites',
    };
	       
    $features2config->{'promoter:promoter'} = {
	include => 'promoter_regions',
    };

    $features2config->{'regulatory_region:regulatory_region'} = {
	include  => 'regulatory_regions',
    };

    $features2config->{'TF_binding_site:TF_binding_site'} = {
	include => 'transcription_factor_binding_site',
    };

    $features2config->{'TF_binding_site:TF_binding_site_region'} = {
	include => 'transcription_factor_binding_region',
    };

################################################
#
# Subcategory: Motifs
#
################################################

    $features2config->{'DNAseI_hypersensitive_site:DNAseI_hypersensitive_site'} = {
	include => 'dnaseI_hypersensitive_site',
    };

    $features2config->{'G_quartet:pmid18538569'} = {
	include => 'g4_motif',
    };

################################################
#
# Subcategory: Translated Features
#
################################################

    $features2config->{'sequence_motif:translated_feature'} = {
	include    => 'protein_motifs',
    };
    
    $features2config->{'translated_nucleotide_match:mass_spec_genome'} = {
	include => 'mass_spec_peptides',
    };


################################################
#
# Category: Expression
#
################################################

    $features2config->{'SAGE_tag:SAGE_tag'} = {		  
	include => 'sage_tags',
    };

    
    $features2config->{'experimental_result_region:Expr_profile'} = {
	include => 'expression_chip_profiles',
    };

    $features2config->{'reagent:Expr_pattern'} = {
	include => 'expression_patterns',
    };

    $features2config->{'transcript_region:RNASeq_reads'} = {
	include => 'rnaseq',
    };

    $features2config->{'intron:RNASeq_splice'} = {
	include => 'rnaseq_splice',
    };

    $features2config->{'transcript_region:RNASeq_F_asymmetry'} = {
	include => 'rnaseq_asymmetries',
	children   => ['transcript_region:RNASeq_R_asymmetry'],
    };

    $features2config->{'mRNA_region:Polysome_profiling'} = {
	include => 'polysomes',
    };

################################################
#
# Category: Genome structure
#
################################################


################################################
#
# Subcategory: Assembly & Curation
#
################################################

    $features2config->{'possible_base_call_error:RNASeq'} = {
	include => 'genome_sequence_errors',
    };

    $features2config->{'base_call_error_correction:RNASeq'} = {
	include => 'genome_sequence_errors_corrected'
    };

    $features2config->{'assembly_component:Link'} = {
	children   => ['assembly_component:Genomic_canonical'],
	include    => 'links_and_superlinks',
    };	

    $features2config->{'assembly_component:Genbank'} = {
	include => 'genbank_entries',
    };

    $features2config->{'assembly_component:Genomic_canonical'} = {
	include => 'genomic_canonical',
    };

    $features2config->{'duplication:segmental_duplication'} = {
	include => 'segmental_duplications',
    };


################################################
#
# Subcategory: Repeats
#
################################################
    
    $features2config->{'low_complexity_region:dust'} = {
	include => 'repeats_dust',
    };
    
    $features2config->{'repeat_region:RepeatMasker'} = {
	include => 'repeats_repeat_masker',
    };

    $features2config->{'inverted_repeat:inverted'} = {
	include => 'repeats_tandem_and_inverted',
	children   => ['tandem_repeat:tandem'],
    };


################################################
#
# Category: Transcription
#
################################################

    $features2config->{'expressed_sequence_match:BLAT_EST_BEST'} = {
	include => 'est_best'
    };

    $features2config->{'expressed_sequence_match:BLAT_EST_OTHER'} = {
	include => 'est_other'
    };

    $features2config->{'expressed_sequence_match:BLAT_mRNA_BEST'} = {
	include => 'mrna_best',
	children   => ['expressed_sequence_match:BLAT_ncRNA_BEST'],
    };

    $features2config->{'expressed_sequence_match:BLAT_ncRNA_OTHER'} = {
	include => 'mrna_other',
	children => ['expressed_sequence_match:BLAT_mRNA_OTHER'],
    };

    $features2config->{'TSS:RNASeq'} = {
	include => 'transcription_start_site',
    };

    $features2config->{'transcription_end_site:RNASeq'} = {
	include => 'transcription_end_site',
    };

    $features2config->{'nucleotide_match:TEC_RED'} = {
	include => 'tecred_tags',
    };

    $features2config->{'five_prime_open_reading_frame:micro_ORF'} = {
	include => 'micro_orf',
    };

    $features2config->{'PCR_product:Orfeome'} = {
	include => 'orfeome_pcr_products',
    };

    $features2config->{'transcribed_fragment:TranscriptionallyActiveRegion'} = {
	include => 'transcriptionally_active_region',
    };

    $features2config->{'expressed_sequence_match:BLAT_OST_BEST'} = {
	includes => 'orfeome_sequence_tags',
    };

    $features2config->{'expressed_sequence_match:BLAT_RST_BEST'} = {
	include => 'race_sequence_tags',
    };


################################################
#
# Category: Sequence similarity
#
################################################
    
    $features2config = $self->create_nucleotide_similarity_stanzas($features2config);
    
    $features2config->{"protein_match:UniProt-BLASTX"} = {
	include => "sequence_similarity_uniprot_blastx",
    };
   
    $features2config->{'expressed_sequence_match:BLAT_Caen_EST_BEST'} = {
	children => ['expressed_sequence_match:BLAT_Caen_mRNA_BEST'],
	include => "sequence_similarity_wormbase_core_ests_and_mrnas_best",
    };
    
    $features2config->{'expressed_sequence_match:BLAT_Caen_EST_OTHER'} = {
	children => ['expressed_sequence_match:BLAT_Caen_mRNA_OTHER'],
	include => "sequence_similarity_wormbase_core_ests_and_mrnas_other",
    };

    $features2config->{'expressed_sequence_match:NEMBASE_cDNAs-BLAT'} = {
	include => "sequence_similarity_nembase_cdnas",
    };

    $features2config->{'expressed_sequence_match:EMBL_nematode_cDNAs-BLAT'} = {
	include => "sequence_similarity_nematode_cdnas",
    };

    $features2config->{'expressed_sequence_match:NEMATODE.NET_cDNAs-BLAT'} = {
	include => "sequence_similarity_nematode_net_cdnas",
    };



################################################
#
# Reagents
#
################################################

    $features2config->{'PCR_product:promoterome'} = {
	include => 'pcr_product_promoterome',
    };

    $features2config->{'reagent:Oligo_set'} = {
	include => 'microarray_oligo_probes',
    };

    # This will require special handling
    $features2config->{'PCR_product'} = {
	include => 'pcr_products',
    };

    # This might ALSO require special handling: overlaps with other tracks
    $features2config->{'region:Vancouver_fosmid'} = {
	children=> [qw/assembly_component:Genomic_canonical/],
	include => 'clones',
    };


    return $features2config;
}




sub create_nucleotide_similarity_stanzas {
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
    }
    return $data;
}




1;

