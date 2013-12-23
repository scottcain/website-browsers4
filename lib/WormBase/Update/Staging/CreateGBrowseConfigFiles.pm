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
	    # Have we already seen this feature? It's a child of a primary feature.
	    # Config has already been added by the parent and the count of the child printed. Move on.
	    next if defined $features->{$feature}->{track_name};
	    
	    # Fetch the stanza for this feature. A single primary feature acts as the key for stanzas
	    my $track_name     = $features2config->{$feature}->{track_name};

	    my ($method,$source) = split(":",$feature);
	           
	    if ($track_name) {

		# Is there a stanza for this track? There should be by definition...
		my $stanza = $features2config->{$feature}->{stanza}; 

		# This species has a feature that requires a new stanza. Merge it into the main config
		$base_config = $self->merge_to_base_config($base_config,"[$track_name]\n$stanza") if $stanza;
		    
		# Add in Zoom stanzas
		if ($features2config->{$feature}->{zoom}) {
		    my $limit = $features2config->{$feature}->{zoom}->{limit};
		    my $stanza = $features2config->{$feature}->{zoom}->{stanza};
		    $base_config = $self->merge_to_base_config($base_config,"[$track_name:$limit]\n$stanza");
		}

		# Merge in per-species overrides (associated with individual features for now)
		# Relocating all exceptions to the species_config data struct
		my $overrides = eval { $features2config->{$feature}->{overrides}->{$species}->{stanza} };
		$base_config = $self->merge_to_base_config($base_config,"[$track_name]\n$overrides") if $overrides;

		# Update stanzas (again) with (possibly) more information specific to this species
		my $species_config = $self->species_config();
		my $this_species = $species_config->{"$species"};		

		# Exceptions are actually keyed out in a hash. 
		foreach my $stanza (keys %{$this_species->{stanzas}}) {
		    foreach my $option (keys %{$this_species->{stanzas}->{$stanza}}) {
			my $value = $this_species->{stanzas}->{$stanza}->{$option};
			# Set/update this value in the base config
			$base_config->set(uc($stanza),$option => $value);
		    }   
		}
		
		# Finally, add unique stanzas		
		my $extra_stanzas = $this_species->{extra_stanzas};
		$base_config = $self->merge_to_base_config($base_config,$extra_stanzas) if $extra_stanzas;

		# Record stats on a per-species basis.
		print $fh join("\t",
			       $feature,
			       "",
			       $source,
			       $method,
			       $track_name,
			       $features->{species}->{$species}->{features}->{$feature}
		    )
		    . "\n"; 
		
		# Record that we've found config for this track.
		$features->{$feature}->{config} = $track_name;

		# Iterate through children of this feature (if there are any)
		# I do this simply to create a nice accounting of features.
		# (I could also fetch these through the config although not all children are listed)
		my @children = eval { @{$features2config->{$feature}->{children}} };
		foreach my $child (@children) {
		    next if $child eq $feature;  # may have already seen.
		    my ($child_method,$child_source) = split(":",$child);
		    print $fh join("\t",
				   "",
				   $child,					     
				   $child_source,
				   $child_method,
				   $track_name,
				   $features->{species}->{$species}->{features}->{$child},
			) . "\n"; 
		    
		    # Mark this feature as seen so it doesn't end up in the output twice.
		    $features->{$child}->{track_name} = $track_name;
		}
	    } else { 		
		# No config found. We are either 
		#   a) a child/sibling/non-primary feature that will be picked up later or
		#   b) a parent feature for which no configuration exists. We should take note of these.
		next;
	    }
	    	   
	}
	undef $fh;

	$self->dump_configuration($species,$base_config);
    }
}


sub merge_to_base_config {
    my ($self,$base_config,$raw_config) = @_;

    my $new_config = WormBase::FeatureFile->new(-text => $raw_config);
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
    print Dumper($config);
    
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
	    
	    # Value is either static or a callback. No way to know which. Try both.
#	    my ($value) = $config->get_callback_source($stanza,$option);
#	    my $value = $config->code_setting($stanza,$option);
#	    $value ||= $config->setting($stanza => $option);
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
	
	# The track name
	my $track_name = $features->{$feature}->{track_name} || '';  # avoid warnings.
	push @values,$track_name;
	
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
    # If you change the track_name here, it will ALSO
    # need to be changed below for any species exceptions
    my $features2config = { };

################################################
#
# Category: Genes
#
################################################
	
    # ALL genes
    $features2config->{'gene:WormBase'} = { 
	track_name => 'PRIMARY_GENE_TRACK',
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
	stanza => q^
key          = Genes
category     = Genes
feature  = gene:WormBase gene:WormBase_imported
glyph = gene
title = sub {
	 my $f = shift;
	 return "Curated transcript " . $f->display_name . "<br /><i>click for details";
	 }
label    = sub { 
		my $f = shift;
		my ($locus)  = $f->attributes('locus');
		my ($name) = $f->attributes('sequence_name');
		return $locus ? "$locus ($name)" : $name;
	}
description  = sub {	     
	my $f = shift;
	my ($biotype) = $f->attributes('biotype');
	$biotype =~ s/_/ /g;
	# Eventually, there should be notes to add as well.
#	my $tags   = join(';',$f->get_all_tags());
#	return $tags;
	return $biotype;	
       }
bgcolor = sub {
	     my $f = shift;
	     my $type = $f->type;
   	     # Component parts:
	     # ncRNAs : gene > ncRNA > exon
	     # coding : gene > mRNA > CDS
	     return 'gray'   if $f->type =~ /exon|pseudogene|ncrna/i;
	     return 'violet' if $f->strand > 0;
	     return 'turquoise';
	     }
fgcolor      = black
utr_color    = gray
font2color   = blue
height  = sub {
	my $f = shift;
	# Component parts:
	# ncRNAs : gene > ncRNA > exon
	# coding : gene > mRNA > CDS
	return $f->type =~ /mRNA|CDS|UTR/i ? 10 : 6;
	}
link = sub {
        my $f = shift;
	my $transcript = $f->name; # Either a WBGene or transcript name

	# We won't link these
	return if $f->type eq 'ncRNA:RNAz';
	
	# Protein coding genes: to gene or transcript?
	my ($locus)  = $f->attributes('locus');

	# We are clicking on the grouped gene: link to the Gene Report
	if ($f->type =~ /Gene/i) {
   	        return "/get?name=$transcript;class=Gene";
            # Otherwsie, we are clicking on a child feature. Link to the transcript.
        } elsif ($transcript && $locus) {
		return "/get?name=$transcript;class=Transcript";
        } else {
    	    return "/get?name=$transcript;class=Gene";
        }
     }
box_subparts = 1
balloon hover  = sub {
	my $f = shift;

	my ($transcript) = $f->attributes('sequence_name');
	$transcript ||= $f->name; 
	
	# In the balloon, provide some additional (conditional) information on
	# each individual transcript
	# We could also, eg, include direct links to protein reports

	my ($locus)  = $f->attributes('locus');
		
	# Biotypes are only associated with gene features.
	# Depending on the current entity, we may not have direct access.
	my $message;
	my $type;
	if ($f->type =~ /gene/i) {
            ($type) = $f->attributes('biotype');
	    $type =~ s/_/ /g;
        } elsif ($f->type =~ /mRNA/i) {
	    $type = 'protein coding';
	    $message = "<i>click to view Transcript Report</i>";
	} 

	# Display some additional information if mousing over a child feature.
	my @return;
	if ($type) {
		push @return,"<b>$transcript</b>";
        	push @return,"Type: $type"            if $type;
 		push @return,"Locus: <i>$locus</i>"   if $locus;
        } else {
		 # top-level feature
		 if ($transcript && $locus) {
	     	    push @return,"<b>$locus ($transcript)</b>";
		 } else {
	     	    push @return,"<b>$transcript</b>";
        	 }    
	     	 push @return,"<i>click to view Gene Report</i>";
         }
	return join("<br />",@return,$message);
     }
^,
	zoom => { limit => 150000,
		  stanza => q^
glyph        = generic
strand_arrow = 1
bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
description  = 0
^,
	    },
    overrides => {
	c_elegans_PRJNA13758 => q^
key = Curated Genes
citation = Protein-coding gene structures result from the integration of a variety 
           of prediction methods and data sources followed by manual review and revison 
           by WormBase curators. tRNAs are predicted by tRNAscan, and other non-coding 
           RNA transcripts are taken from a variety of literature sources. 
           The purple and blue colors indicate transcripts on the forward and 
           reverse strands respectively. If sufficient room is available between 
           features, gene models end with a triangle; if not a small arrow is used. 
           Grey areas represent 5' and 3' UTRs of protein-coding transcripts, assigned  
           automatically using the extents of overlapping ESTs and full-length cDNAs. The 
           UTR predictions have not been reviewed by WormBase curators, and some are 
           known to contain artifacts.
^,
},
    };
    
    $features2config->{'ncRNA:WormBase'} = { 
	track_name => 'GENES_NONCODING',
	children   => [ 'miRNA:WormBase',
			'rRNA:WormBase', 
			'scRNA:WormBase',
			'snRNA:WormBase',
			'snoRNA:WormBase',
			'tRNA:WormBase',
			'exon:WormBase',
			'intron:WormBase'
	    ],
			    stanza => q^
key          = Genes (noncoding)
category     = Genes
feature = miRNA:WormBase
          ncRNA:WormBase        
          rRNA:WormBase
          scRNA:WormBase
          snRNA:WormBase
          snoRNA:WormBase
          tRNA:WormBase
glyph = gene
title = sub {
	 my $f = shift;
	 return "Curated transcript " . $f->display_name . "<br /><i>click for details";
	 }
link = sub {
        my $f = shift;
        my $name = $f->attributes('Gene') || $f->name;
        return "/get?name=$name;class=Gene";
        }
label = sub { 
        my $f = shift;
        my ($locus)  = $f->attributes('locus');
        my ($name)   = $f->display_name;
        return $locus ? "$locus ($name)" : $name;
        }
description  = sub {             
        my $f = shift;
        my $type = $f->type;
        # Component parts:
        # ncRNAs : gene > ncRNA > exon
        return $f->method;  # please, someone explain why this works ;) Bio::DB::GFF backwards compat?
        # This does NOT work in this context. Biotype 
        # is an attribute of gene, not CDS.
        # my ($biotype) = $f->attributes('biotype');
        # or...
        # $f->get_tag_values('biotype'));
        # $biotype =~ s/_/ /g;
        # my $tags   = join(';',$f->get_all_tags());
        # return $biotype;        
	# Eventually, there should be notes to add as well.
	# my $tags   = join(';',$f->get_all_tags());
	# return $tags;
       }
bgcolor = sub {
             my $f = shift;
             my $type = $f->type;
                # Component parts:
             # ncRNAs : gene > ncRNA > exon
             # coding : gene > mRNA > CDS
             return 'gray'   if $f->type =~ /exon|pseudogene/i;
             return 'violet' if $f->strand > 0;
             return 'turquoise';
             }
fgcolor      = black
utr_color    = gray
font2color   = blue
height  = sub {
        my $f = shift;
        # Component parts:
        # ncRNAs : gene > ncRNA > exon
        # coding : gene > mRNA > CDS
        return $f->type =~ /mRNA|CDS|UTR/i ? 10 : 6;
        }
balloon hover  = sub {
	my $f = shift;

	my ($transcript) = $f->display_name; 
	my ($locus)  = $f->attributes('locus');
		
	my @return;
	if ($transcript && $locus) {
	       push @return,"<b>$locus ($transcript)</b>";
	} else {
	       push @return,"<b>$transcript</b>";
        }    
	push @return,"<i>click to view Gene Report</i>";        
	return join("<br />",@return);
     }
citation = Non-coding curated gene models, including ncRNA, tRNA, miRNA, snRNA, snoRNA.
^,
    zoom => { limit  => 150000,
	      stanza => q^ 
glyph        = generic
strand_arrow = 1
bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
description  = 0
^,
},
    overrides => { 
	c_elegans_PRJNA13758 => q^
key = Curated Genes (noncoding)
^,
},
    };

    $features2config->{'pseudogenic_transcript:WormBase'} = { 
	track_name => 'GENES_PSEUDOGENES',
	stanza => q^
key      = Genes (pseudogenes)
category = Genes
feature  = pseudogenic_transcript:WormBase
glyph = gene
title = sub {
	 my $f = shift;
	 return "Curated pseudogene " . $f->display_name . "<br /><i>click for details";
	 }
link = sub {
        my $f = shift;
        my $name = $f->attributes('Gene') || $f->name; 
        return "/get?name=$name;class=Gene";
        }
label = sub { 
        my $f = shift;
        my ($locus)  = $f->attributes('locus');
        my ($name)   = $f->display_name;
        return $locus ? "$locus ($name)" : $name;
        }
description  = sub {             
        my $f = shift;
  	return 'pseudogene';
  
        # eventually maybe also descriptions
        # my $tags   = join(';',$f->get_all_tags());
       }
bgcolor = sub {
             my $f = shift;
             my $type = $f->type;
                # Component parts:
             # ncRNAs : gene > ncRNA > exon
             # coding : gene > mRNA > CDS
             return 'gray'   if $f->type =~ /exon|pseudogene/i;
             return 'violet' if $f->strand > 0;
             return 'turquoise';
             }
fgcolor      = black
utr_color    = gray
font2color   = blue
height  = sub {
        my $f = shift;
        # Component parts:
        # ncRNAs : gene > ncRNA > exon
        # coding : gene > mRNA > CDS
        return $f->type =~ /mRNA|CDS|UTR/i ? 10 : 6;
        }
balloon hover  = sub {
	my $f = shift;

	my ($transcript) = $f->display_name; 
	my ($locus)  = $f->attributes('locus');
		
	my @return;
	if ($transcript && $locus) {
	       push @return,"<b>$locus ($transcript)</b>";
	} else {
	       push @return,"<b>$transcript</b>";
        }    
	push @return,"<i>click to view Gene Report</i>";        
	return join("<br />",@return);
     }
citation = A subset of the full Curated Genes set limited to pseudogenes only.
^,
    zoom => { limit => 150000,
	      stanza => q^
glyph        = generic
strand_arrow = 1
bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
description  = 0
^,
},
    overrides => { 
	c_elegans_PRJNA13758 => q^
key = Curated Genes (pseudogenes)
^,
},
    };

# Protein coding genes
    $features2config->{'CDS:WormBase'} = {
	track_name => 'GENES_PROTEIN_CODING',
	children   => ['CDS:WormBase_imported'],
	stanza     => q^
key     = Genes (protein coding)
category     = Genes
feature = CDS:WormBase
glyph = gene
title = sub {
	 my $f = shift;
	 return "Curated transcript " . $f->display_name . "<br /><i>click for details";
	 }
label    = sub { 
		my $f = shift;
		my ($locus)  = $f->attributes('locus');
		my ($name) = $f->display_name;
		return $locus ? "$locus ($name)" : $name;
        }	
link = sub {
        my $f = shift;
        my $name = $f->attributes('Gene') || $f->name;
        return "/get?name=$name;class=Gene";
        }
description  = sub {             
        my $f = shift;
        my $type = $f->type;
        # Component parts:
        # coding : gene > mRNA > CDS
	return 'protein coding';

	# Eventually, there should be notes to add as well.
#	my $tags   = join(';',$f->get_all_tags());
#	return $tags;
       }
bgcolor = sub {
             my $f = shift;
             my $type = $f->type;
                # Component parts:
             # ncRNAs : gene > ncRNA > exon
             # coding : gene > mRNA > CDS
             return 'gray'   if $f->type =~ /exon|pseudogene/i;
             return 'violet' if $f->strand > 0;
             return 'turquoise';
             }
fgcolor      = black
utr_color    = gray
font2color   = blue
height  = sub {
        my $f = shift;
        # Component parts:        
        # coding : gene > mRNA > CDS
        return $f->type =~ /mRNA|CDS|UTR/i ? 10 : 6;
        }
balloon hover  = sub {
	my $f = shift;

	my ($transcript) = $f->display_name; 
	my ($locus)  = $f->attributes('locus');
		
	my @return;
	if ($transcript && $locus) {
	       push @return,"<b>$locus ($transcript)</b>";
	} else {
	       push @return,"<b>$transcript</b>";
        }    
	push @return,"<i>click to view Gene Report</i>";        
	return join("<br />",@return);
     }
citation = A subset of the full Curated Genes set limited to protein-coding genes only.
           Only the CDS is represented. Full models (with UTRs) can be seen on the 
	   "Curated Genes" track.
^,
	   zoom => { limit => 150000,
		     stanza => q^
glyph        = generic
strand_arrow = 1
bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
description  = 0
^,
       },    
    overrides => { 
	c_elegans_PRJNA13758 => q^
key = Curated Genes (protein coding)
^,
},
    };

# This track shows the approximate physical span of genetic intervals
# It is restricted to C. elegans.  
    $features2config->{'gene:interpolated_map_position'} = { 
	track_name => 'GENETIC_LIMITS',
	children   => [ qw/gene:absolute_map_position/ ],
	stanza => q^
# This track shows the approximate physical span of genetic intervals
# It is restricted to C. elegans.
key           = Genetic limits
category      = Genes
feature       = gene:interpolated_pmap_position
		gene:absolute_pmap_position
glyph         = sub {
                    my $f = shift;
                    return ($f->source eq 'interpolated_pmap_position') ? 'span' : 'box';
       }
fgcolor       = black
bgcolor       = sub { my $f = shift;
		      return ($f->source eq 'interpolated_pmap_position') ? 'red' : 'turquoise';
	}
link          = sub { my $f   = shift;
                      my $name = $f->name;
   	              return "/get?name=$name;class=Gene";
	}
height        = 3
label         = sub { my $f = shift;
	      	      my ($status) = $f->attributes('status');
		      my ($gmap)   = $f->attributes('gmap');
		      return "$gmap ($status)";
	}
description   = sub { my $f = shift;
	              my $position = join(' ',$f->notes);
		      return $position;
        }
citation      = This track shows the maximal extents for genetic loci.  
		Loci that have been interpolated onto the physical
                map (and whose precise location is unknown) are shown 
                as a thin black span.  The physical extent of such loci are determined 
                by interpolating their genetic position onto the physical 
                map using 95% confidence limits.  Please note that the actual 
                location of such loci may lay outside of the span depicted.
                Loci with known sequence connections are shown in turquoise 
                and depicted using the physical span of the gene.
^,
    };
    
    $features2config->{'CDS:Genefinder'} = {
	track_name => 'PREDICTION_GENEFINDER',
	stanza => q^
key          = Prediction: GeneFinder
category     = Genes
feature      = CDS:Genefinder
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
^,
zoom         => { limit => 75000,
		  stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
},
};    
    
    $features2config->{'CDS:GeneMarkHMM'} = {
	track_name => 'PREDICTION_GENEMARKHMM',
	stanza => q^
key          = Prediction: GeneMarkHMM
category     = Genes
feature      = CDS:GeneMarkHMM
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
citation     = These are GeneMarkHMM gene predictions provided by Mark Borodovsky. 
^,
zoom  => { limit => 75000,
	   stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
},
};			 
    
    $features2config->{'CDS:Jigsaw'} = {
	track_name => 'PREDICTION_JIGSAW',
	stanza => q^
key          = Prediction: Jigsaw
category     = Genes
feature      = CDS:Jigsaw
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
^,
zoom         => { limit => 75000,
		  stanza => q^
 glyph        = box
 strand_arrow = 1
 link         = 0
 ^,
},
    };

    $features2config->{'CDS:mGene'} = {
	track_name => 'PREDICTION_MGENE',
	stanza => q^
key          = Prediction: mGene
category     = Genes
feature      = CDS:mGene
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
^,
zoom         => { limit => 75000,
		  stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
},
    };

    $features2config->{'CDS:mSplicer_orf'} = {
	track_name => 'PREDICTION_MSPLICER_ORF',
	stanza => q^
key          = Prediction: mSplicer-ORF
category     = Genes
feature      = CDS:mSplicer_orf
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
citation     = mSplicer predict the splice forms for a given start and
	       end of a transcript. (Note that it is not yet a
               full-featured gene-finder.) There are two versions:
               1. "mSplicer" which splices general pre-mRNA (including
               UTR or coding regions) without assuming the existence of a
               reading frame (requires transcription start and stop).
               2. "mSplicer-ORF" is optimized for coding regions and
               requires the knowledge of the translation start and stop.
               These predictions were generated against regions annotated
               in WS160. More details can be found at <a href="http://www.fml.mpg.de/raetsch/projects/msplicer">http://www.fml.mpg.de/raetsch/projects/msplicer</a>.
^,
	       zoom         => { limit => 75000,
				 stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
	   },
    };

    $features2config->{'CDS:mSplicer_transcript'} = {
	track_name => 'PREDICTION_MSPLICER_TRANSCRIPT',
	stanza => q^
key          = Prediction: mSplicer
category     = Genes
feature      = CDS:mSplicer_transcript
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
citation     = mSplicer predict the splice forms for a given start and
	       end of a transcript. (Note that it is not yet a
               full-featured gene-finder.) There are two versions:
               1. "mSplicer" which splices general pre-mRNA (including
               UTR or coding regions) without assuming the existence of a
               reading frame (requires transcription start and stop).
               2. "mSplicer-ORF" is optimized for coding regions and
               requires the knowledge of the translation start and stop.
               These predictions were generated against regions annotated
               in WS160. More details can be found at <a href="http://www.fml.mpg.de/raetsch/projects/msplicer">http://www.fml.mpg.de/raetsch/projects/msplicer</a>.
^,	       
	       zoom         => { limit => 75000,
				 stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
	   },
    };

    $features2config->{'twinscan:CDS'} = {
	track_name => 'PREDICTION_TWINSCAN',
	stanza => q^
key          = Prediction: Twinscan
category     = Genes
feature      = CDS:twinscan
glyph        = gene
bgcolor      = palevioletred
fgcolor      = palevioletred
link         = 0
^,
zoom         => { limit => 75000,
		  stanza => q^
glyph        = box
strand_arrow = 1
link         = 0
^,
},
    };

    $features2config->{'ncRNA:RNAz'} = {
	track_name => 'RNAz',
	stanza => q^
key          = RNAz non-coding RNA genes
category     = Genes
feature      = ncRNA:RNAz
glyph        = transcript
bgcolor      = white
fgcolor      = black
forwardcolor = violet
reversecolor = cyan
utr_color    = gray
font2color   = blue
label        = sub { 
		my $f = shift;
		my $name = $f->display_name;
		return $name;
	}
description = sub {
	my $f = shift;
	my $notes = join ' ',$f->notes;
	return $notes;
    }
link   = 0
citation     = RNAz-derived ncRNAs were predicted using
        the <a href="http://www.tbi.univie.ac.at/~wash/RNAz/">RNAz algorithm</a>.
        Please select the RNA for more details.
^,
    };
	
    $features2config->{'transposable_element:Transposon'} = { 
	track_name => 'TRANSPOSONS',	    
	stanza => q^
key          = Transposons
category     = Genes
feature      = transposable_element:Transposon
glyph        = segments
bgcolor      = gray
fgcolor      = black
utr_color    = gray
font2color   = blue
height       = 6
title        = Transposon $name
label        = sub { 
 	        my $f = shift;
		my $name = $f->display_name;
		return $name;
	}
# Nothing currently available.
#description  = 0
# No Gene attribute available
#link = sub {
#	my $f = shift;	
#	my $name = $f->attributes('Gene') || $f->name;
#	return "/get?name=$name;class=Gene";
#	}
citation = These are transposon spans reviewed by WormBase curators.
^,
    zoom => { limit  => 150000,
	      stanza => q^
glyph        = generic
strand_arrow = 1
bgcolor      = gray
description  = 0
^,
},
    };	
	
    $features2config->{'transposable_element_CDS:WormBase_transposon'} = { 
	track_name => 'TRANSPOSON_GENES',	    
	children   => qw[/transposable_element_Pseudogene:WormBase_transposon/],
	stanza => q^
key          = Transposon Genes
category     = Genes
feature      = transposable_element_CDS:WormBase_transposon transposable_element_Pseudogene:WormBase_transposon
# NOT using the gene glyph since there are no CDS components.
glyph        = transcript
bgcolor      = gray
fgcolor      = black
utr_color    = gray
font2color   = blue
height       = 6
balloon hover  = sub {
                      my $f    = shift;
	              my $name = $f->name;                       
		      my $s    = $f->type;
		      my $type = $s =~ /CDS/ ? 'transposon CDS' : 'transposon pseudogene';
    		      my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		      my $notes = $f->notes;
		      my $string = join('<br />',"<b>$name</b>",$type,"position: $ref:$start..$stop",
		      	 "notes: $notes");
	 	      return $string;    		      
	       } 
title    = Transposon $name
label    = sub { 
		my $f = shift;
		my $name = $f->display_name;
		return $name;
	}
description  = sub {	     
                      my $f    = shift;
		      my $s    = $f->type;
		      my $type = $s =~ /CDS/ ? 'transposon CDS' : 'transposon pseudogene';
		      return $type;
                }
link = sub {
	my $f = shift;	
	my $name = $f->attributes('Gene') || $f->name;
	return "/get?name=$name;class=Gene";
	}
citation = These are transposon spans reviewed by WormBase curators.
^,
    zoom => { limit  => 150000,
	      zoom => q^
glyph        = generic
strand_arrow = 1
bgcolor      = gray
description  = 0
^,
},
    };
	
    $features2config->{'operon:operon'} = {
	track_name => 'OPERONS',
	stanza => q^
key          = Operons
category     = Genes
feature      = operon:operon
glyph        = generic
strand_arrow = 1
bgcolor      = green
height       = 10
description  = 1
^,
overrides => {
    c_elegans_PRJNA13758 => q^
citation     = These are operons published by Blumenthal et al, Nature 417: 851-854 (2002).
^,
},
    };

    $features2config->{'operon:deprecated_operon'} = {
	track_name => 'OPERONS_DEPRECATED',
	stanza => q^
key          = Operons (deprecated)
category     = Genes
feature      = operon:deprecated_operon
glyph        = generic
strand_arrow = 1
bgcolor      = green
height       = 10
description  = 1
citation     = These are historical operon predictions.
^,
    };
	
    $features2config->{'polyA_signal_sequence:polyA_signal_sequence'} = {
	track_name =>  'POLYA_SITES',
	children   => ['polyA_site:polyA_site'],
	stanza => q^
key          = PolyA sites and signal sequences
category     = Genes
feature      = polyA_signal_sequence polyA_site
glyph        = sub {
		my $f = shift;
		return 'diamond' if $f->type =~ /signal/;
		return 'dot' if $f->strand eq '0';
		return 'triangle';
	}
description  = sub { my $s = shift->source; $s=~tr/_/ /; $s; }
point        = 1
orient       = sub {
		my $f = shift;
		return if $f->type =~ /signal/;
		return 'W' if $f->strand eq '-1';
		return 'E';
	}
bgcolor      = purple
link         = sub { my $f   = shift;
                      my $name = $f->name;
   	              return "/get?name=$name;class=Feature";
	}
citation     = High-confidence polyadenylation signal sequences and sites calculated 
	       by an algorithm trained with verified sites from full-length mRNAs. Signals
	       are indicated with a diamond; sites with a triangle.	    
^,
    };
	       
    $features2config->{'SL1_acceptor_site:SL1'} = {
	track_name => 'TRANS_SPLICED_ACCEPTOR',
	children   => ['SL2_acceptor_site:SL2'],
	stanza => q^
key          = Trans-spliced acceptor
category     = Genes
feature      = SL1_acceptor_site SL2_acceptor_site
glyph        = triangle
point        = 1
orient       = sub {
	my $f = shift;
	my $strand  = $f->strand;
	return 'E' if $strand > 0;
	return 'W';
	}
bgcolor      = sub {
	    my $f = shift;
            return $f->source eq 'SL1' ? 'red' : 'green';
	}
font2color   = 'red';
height       = 8
label        = 0
label density = 100
description  = sub {
		shift->source;
	}
link         = sub { my $f   = shift;
                      my $name = $f->name;
   	              return "/get?name=$name;class=Feature";
	}
citation     = These are SL1 and SL2 trans-spliced acceptors published by Blumenthal et al, 
	       Nature 417: 851-854 (2002). SL1 acceptors are show in red, SL2 in green.
^,
    };
	
    # This should pick up all history entries
    $features2config->{'exon:history'} = {
	track_name => 'HISTORICAL_GENES',
	children   => ['pseudogenic_transcript:history',
		       'transposable_element:history',
		       'protein_coding_primary_transcript:history',
		       'primary_transcript:history',
		       'nc_primary_transcript:history'],
	stanza => q^
key          = Genes (historical)
category     = Genes
feature  = pseudogenic_transcript:history
	   transposable_element:history
	   protein_coding_primary_transcript:history
	   primary_transcript:history
	   nc_primary_transcript:history
glyph        = transcript
title        = Historical gene prediction $name
bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
fgcolor      = black
utr_color    = gray
font2color   = blue
height       = 10
#sub {
#	my $f = shift;
#	return $f->method =~  /transcript|UTR|coding_exon/i ? 10 : 6;
#	}
balloon hover  = sub {
	my $f = shift;
	my $name = $f->name; 
        my $method = $f->method;
	$method =~ s/_/ /g;
	return "<b>Historical gene prediction</b><br>$name<br>$method";
	} 
label    = sub { 
		my $f = shift;
		my $name = $f->display_name;
		return $name;
	}
description  = sub {	     
	my $f = shift;
	my $method = $f->method;
	$method =~ s/_/ /g;
        return "$method";
    }
citation = Historical gene predictions.
^,
    zoom => { limit => 150000,
	      stanza => q^
glyph        = generic
strand_arrow = 1
#bgcolor      = sub {shift->strand>0?'violet':'turquoise'}
bgcolor       = white
description = 0
^,
},
    };


################################################
#
# Category: Variations
#
################################################
    $features2config->{'substitution:Allele'} = {
	track_name => 'CLASSICAL_ALLELES',
	children   => ['deletion:Allele',
		       'insertion_site:Allele',
		       'substitution:Allele',
		       'complex_substitution:Allele',
		       'transposable_element_insertion_site:Allele'],
	stanza => q&
key          = Classical alleles
category     = Alleles, Variations, RNAi
feature      = deletion:Allele
	       insertion_site:Allele
	       substitution:Allele
	       complex_substitution:Allele
	       transposable_element_insertion_site:Allele
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m eq 'insertion_site';
		return 'triangle' if $m eq 'mobile_element_insertion';
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
bgcolor      = sub {
		my $f = shift;
		my $m = $f->method;
		return 'red'    if $m eq 'deletion';
		return 'yellow' if $m eq 'point_mutation';
		return 'yellow' if $m eq 'substitution';
		return 'blue'   if $m eq 'complex_substitution';		
		return 'white'; # insertion_site, mobile_element_insertion
	}
fgcolor      = black
font2color   = blue
height       = 8
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->type;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>Allele: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation      = This track shows classical alleles comprised of insertions, deletions,
	        substitutions and complex changes. These alleles were typically generated
		during forward genetic screens.
		Red boxes represent deletions; yellow diamonds represent substitutions; 
		blue boxes represent complex substitutions; and white triangles represent
		insertions.
&,
    };
		
    $features2config->{'deletion:KO_Consortium'} = {
	track_name => 'HIGH_THROUGHPUT_ALLELES',
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
			   stanza => q&
key          = High-throughput alleles
category     = Alleles, Variations, RNAi
feature      = deletion:CGH_allele
	       complex_substitution:KO_consortium
	       deletion:KO_consortium
	       point_mutation:KO_consortium
	       deletion:Variation_project
	       insertion_site:Variation_project
	       point_mutation:Variation_project
	       complex_substitution:NBP_knockout
	       deletion:NBP_knockout
	       transposable_element_insertion_site:NemaGENETAG_consortium
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m eq 'insertion_site';
		return 'triangle' if $m eq 'mobile_element_insertion';
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
bgcolor      = sub {
		my $f = shift;
		my $m = $f->method;
		return 'red'    if $m eq 'deletion';
		return 'yellow' if $m eq 'point_mutation';
		return 'yellow' if $m eq 'substitution';
		return 'blue'   if $m eq 'complex_substitution';		
		return 'white'; # insertion_site, mobile_element_insertion
	}
fgcolor      = black
font2color   = blue
height       = 8
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->method;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>High-Throughput Allele: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation      = These are alleles generated through high-throughput, genome-wide projects. Million Mutation Project alleles are placed in a separate track.
&,
    };


    $features2config->{'deletion:PCoF_Allele'} = {
	track_name => 'CHANGE_OF_FUNCTION_ALLELES',
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
	stanza => q&
feature =         complex_substitution:PCoF_Allele
                              deletion:PCoF_Allele
                        insertion_site:PCoF_Allele
                          substitution:PCoF_Allele
   transposable_element_insertion_site:PCoF_Allele
                              deletion:PCoF_CGH_allele
                  complex_substitution:PCoF_KO_consortium
                              deletion:PCoF_KO_consortium
                        point_mutation:PCoF_KO_consortium
                        point_mutation:PCoF_Million_mutation
                              deletion:PCoF_Million_mutation
                        insertion_site:PCoF_Million_mutation
                  complex_substitution:PCoF_Million_mutation
                   sequence_alteration:PCoF_Million_mutation
                              deletion:PCoF_Variation_project
                        point_mutation:PCoF_Variation_project
                  complex_substitution:PCoF_NBP_knockout
                              deletion:PCoF_NBP_knockout
              transposable_element_insertion_site:PCoF_NemaGENETAG_consortium
category     = Alleles, Variations, RNAi
key          = Change-of-function alleles
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m =~ /insertion/i;  # insertion_site mobile_element_insertion tranposable_element_insertion
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
bgcolor      = sub {
		my $f = shift;
		my $m = $f->method;
	        my %attributes = $f->attributes();
		return 'green'  if $attributes{consequence} eq 'missense';
		return 'yellow' if $attributes{consequence} eq 'coding_exon';
		return 'red'    if $attributes{consequence} eq 'nonsense';
		return 'blue'   if $attributes{consequence} eq 'frameshift';
		return 'white'; # insertion_site, mobile_element_insertion	
#		return 'red'    if $m eq 'deletion';
#		return 'yellow' if $m eq 'point_mutation';
#		return 'yellow' if $m eq 'substitution';
#		return 'blue'   if $m eq 'complex_substitution';		
#		return 'white'; # insertion_site, mobile_element_insertion
	}
fgcolor      = black
font2color   = blue
height       = 8
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->method;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;
		   $sanitized_source =~ s/PCoF_//g;

		   my @notes = ("<b>Putative Change-of-Function Allele: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation      = This track shows alleles that generate a putative change-of-function.
	        In this track, the type of mutation is indicated by its glyph: Boxes are
 		deletions. Triangles are insertions. Point mutations and substitutions 
		are diamonds. Color shows the potential effect on coding regions.
                Green indicates a possible missense; red a possible
 		nonsense; blue a frameshift; yellow a disruption of a coding exon(s); and
		white for everything else. Mouse over the feature for details.
&,
    };

    $features2config->{'substitution:Variation_project_Polymorhpism'} = {
	track_name => 'POLYMORPHISMS',
	children   => ['deletion:CGH_allele_Polymorhpism',
		       'substitution:Variation_project_Polymorhpism',
		       'deletion:Variation_project_Polymorhpism',
		       'SNP:Variation_project_Polymorhpism',
		       'insertion_site:Variation_project_Polymorhpism',
		       'complex_substitution:Variation_project_Polymorhpism',
		       'sequence_alteration:Variation_project_Polymorhpism',
		       'deletion:Allele_Polymorhpism'],
	stanza => q&
# Polymorphism was MISSPELLED IN WS240. Update to correct spelling for WS241.
key          = Polymorphisms
category     = Alleles, Variations, RNAi
feature      = deletion:CGH_allele_Polymorhpism
           substitution:Variation_project_Polymorhpism
               deletion:Variation_project_Polymorhpism
                    SNP:Variation_project_Polymorhpism
         insertion_site:Variation_project_Polymorhpism
   complex_substitution:Variation_project_Polymorhpism
   sequence_alteration:Variation_project_Polymorhpism
	       deletion:Allele_Polymorhpism
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $attributes{other_name} || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m eq 'insertion_site';
		return 'triangle' if $m eq 'mobile_element_insertion';
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
fgcolor      = black
font2color   = blue
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->method;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>Polymorphism: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
bgcolor      = sub {
		my $f = shift;	
		my ($strain) = $f->attributes('strain');
		if ($strain eq 'CB4858' || $strain eq 'AF16') {
		    return 'blue';
		} elsif ($strain eq 'CB4856' || $strain eq 'HK104') {
		    return 'yellow';
                } else {
		    return 'white';
                } 
	}
height       = sub {
	        my $f = shift;
		my %attributes = $f->attributes();

                # Confirmed, RFLP SNPs
                if (defined $attributes{rflp} and $attributes{status} eq 'Confirmed') {
	               return 14;
                } else {
		    return 8;
                }
        }	
&,
    };
    
    $features2config->{'deletion:PCoF_Variation_project_Polymorhpism'} = {
	track_name => 'CHANGE_OF_FUNCTION_POLYMORPHISMS',
	children   => ['deletion:PCoF_CGH_allele_Polymorhpism',
		       'deletion:PCoF_Variation_project_Polymorhpism',
		       'insertion_site:PCoF_Variation_project_Polymorhpism',
		       'SNP:PCoF_Variation_project_Polymorhpism',
		       'substitution:PCoF_Variation_project_Polymorhpism',
		       'complex_substitution:PCoF_Variation_project_Polymorhpism',
		       'sequence_alteration:PCoF_Variation_project_Polymorhpism'],
	stanza => q&
feature =     deletion:PCoF_CGH_allele_Polymorhpism
              deletion:PCoF_Variation_project_Polymorhpism
        insertion_site:PCoF_Variation_project_Polymorhpism
                   SNP:PCoF_Variation_project_Polymorhpism
          substitution:PCoF_Variation_project_Polymorhpism
  complex_substitution:PCoF_Variation_project_Polymorhpism
   sequence_alteration:PCoF_Variation_project_Polymorhpism
category     = Alleles, Variations, RNAi
key          = Change-of-function polymorphisms
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m eq 'insertion_site';
		return 'triangle' if $m eq 'mobile_element_insertion';
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
bgcolor      = sub {
		my $f = shift;
		my $m = $f->method;
	        my %attributes = $f->attributes();
		return 'green'  if $attributes{consequence} eq 'Missense';
		return 'yellow' if $attributes{consequence} eq 'Coding_exon';
		return 'red'    if $attributes{consequence} eq 'Nonsense';
		return 'blue'   if $attributes{consequence} eq 'Frameshift';
		return 'white'; # insertion_site, mobile_element_insertion	
#		return 'red'    if $m eq 'deletion';
#		return 'yellow' if $m eq 'point_mutation';
#		return 'yellow' if $m eq 'substitution';
#		return 'blue'   if $m eq 'complex_substitution';		
#		return 'white'; # insertion_site, mobile_element_insertion
	}
fgcolor      = black
font2color   = blue
height       = 8
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->type;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_polymorphism//ig;
		   $sanitized_source =~ s/PCoF_//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>Putative Change-of-Function Allele: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation     = This track shows single nucleotide polymorphisms (SNPs) that may generate
 	       a change of function.
               In this track, the molecular nature of the polymorphism is indicated by
               its glyph: Boxes are deletions; triangles are insertions; point mutations
                and substitutions are diamonds. Color shows the potential effect on coding regions.
                Green indicates a possible missense; red a possible
 		nonsense; blue a frameshift; yellow a disruption of a coding exon(s); and
		white for everything else. Mouse over the feature for details.
&,
    };

    $features2config->{'transposable_element_insertion_site:Allele'} = {
	track_name => 'TRANSPOSON_INSERTION_SITES',
	children   => ['transposable_element_insertion_site:Mos_insertion_allele',
		       'transposable_element_insertion_site:Allele',
		       'transposable_element_insertion_site:NemaGENETAG_consortium'],
	stanza => q&
feature      = transposable_element_insertion_site:Mos_insertion_allele
               transposable_element_insertion_site:Allele
	       transposable_element_insertion_site:NemaGENETAG_consortium
category     = Alleles, Variations, RNAi
key          = Transposon insert sites
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $method = $f->method;
		return 'Mos insertion' if $f->source eq 'Mos_insertion_allele';
		return 'NemaGENETAG insertion' if $f->source eq 'NemaGENETAG_consortium';
		return 'transposon insertion';
 	}
glyph        = diamond
bgcolor      = sub {
		my $f = shift;
		return 'yellow' if $f->source eq 'Mos_insertion_allele';
		return 'red' if $f->source eq 'NemaGENETAG_consortium';
		return 'blue';
	}
fgcolor      = black
font2color   = blue
height       = 8
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->type;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>Transposon insertion site: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation     = This track shows transposon insertion sites engineered by
               Laurent Segalat and others 
               [<a href="/get?name=%5Bwm99ab757%5D;class=Paper">Alvarez et al.</a>, Towards a genome-wide collection of transposon insertions, International C. elegans Meeting 1999 #757].
	      Yellow triangles are Mos-derived transposon insertions; red trangles are
	      NemaGENETAG consortium insertion sites;
              blue triangles are Tc* derived transposon insertions.
&,
    };

    $features2config->{'point_mutation:Million_mutation'} = {
	track_name => 'MILLION_MUTATION_PROJECT',
	children   => ['point_mutation:Million_mutation',
		       'complex_substitution:Million_mutation',
		       'deletion:Million_mutation',
		       'insertion_site:Million_mutation',
		       'sequence_alteration:Million_mutation'],
	stanza => q&
feature      =       point_mutation:Million_mutation
               complex_substitution:Million_mutation
                           deletion:Million_mutation
                     insertion_site:Million_mutation
                sequence_alteration:Million_mutation
category     = Alleles, Variations, RNAi
key          = Million Mutation Project
label        = sub {
	     my $f = shift;
	     my %attributes = $f->attributes;
	     my $name = $attributes{public_name} || $f->name;
	     if ($name =~ /^WBVar/) {
	         ($name) = $f->attributes('other_name') || $name;
             }	     
	     return join('-',@$name);   
	      }	      
description  = sub {
		my $f = shift;
		my $m = $f->method;
		$m =~ s/_/ /g;
		return $m;
 	}
glyph        = sub {
		my $f = shift;
		my $m = $f->method;
		return 'triangle' if $m eq 'insertion_site';
		return 'triangle' if $m eq 'mobile_element_insertion';
		return 'box'      if $m eq 'complex_substitution';
		return 'box'      if $m eq 'deletion';
		return 'diamond'  if $m eq 'substitution';
		return 'diamond'  if $m eq 'point_mutation';
		return 'generic';
	}
bgcolor      = sub {
		my $f = shift;
		my $m = $f->method;
	        my %attributes = $f->attributes();
		return 'green'  if $attributes{consequence} eq 'missense';
		return 'yellow' if $attributes{consequence} eq 'coding_exon';
		return 'red'    if $attributes{consequence} eq 'nonsense';
		return 'blue'   if $attributes{consequence} eq 'frameshift';
		return 'white'; # insertion_site, mobile_element_insertion	
#		return 'red'    if $m eq 'deletion';
#		return 'yellow' if $m eq 'point_mutation';
#		return 'yellow' if $m eq 'substitution';
#		return 'blue'   if $m eq 'complex_substitution';		
#		return 'white'; # insertion_site, mobile_element_insertion
	}
fgcolor      = black
font2color   = blue
height       = 8
link         = sub {
                  my $f = shift;
                  my $name = $f->name;
                  return "/get?name=$name;class=Variation";
      }
balloon hover = sub {
	           my $f    = shift;
		   my $type = $f->type;
		   $type =~ s/_/ /g;

		   my ($name)        = $f->attributes('public_name');
		   #$name ||= $f->display_name;
		   my ($consequence) = $f->attributes('consequence');
		   $consequence =~ s/_/ /g;

		   my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
		   my ($status)    = $f->attributes('status');
		   my ($nt_change) = $f->attributes('substitution') || $f->attributes('insertion');
		   my ($aa_change) = $f->attributes('aachange');
		   my ($interpolated_map_position) = $f->attributes('interpolated_map_position');

		   # We might want to be a little fancier with sources, like linking to the resource.
                   my $source = $f->source; 
		   my $sanitized_source = $source;
		   $sanitized_source =~ s/_Polymorphisms//g;
		   $sanitized_source =~ s/_/ /g;

		   my @notes = ("<b>Million Mutation SNP: $name</b>");
		   push (@notes,"type: $type");
		   push (@notes,"status: $status")                  if $status;
		   push (@notes,"position: $ref:$start..$stop");
		   push (@notes,"nucleotide change: $nt_change")     if $nt_change;
		   push (@notes,"amino acid change: $aa_change")     if $aa_change;
           	   push (@notes,"consequence: " . lc($consequence)) if $consequence;
           	   push (@notes,"interpolated map position: $interpolated_map_position")   if $interpolated_map_position;
		   my ($strains) = $f->attributes('strain');
		   if ($strains) {
		      my $strains = join(', ',map { '<a href="http://www.wormbase.org/db/get?class=Strain;name=' . $_ . '">' . $_ . '</a>' } split(',',$strains));
		      push @notes,"strains: $strains"; 
		   }

		   push (@notes,"source: $sanitized_source");  # maybe a link to resource, too?	
		   return join('<br />',@notes);
	}
citation     = This track shows SNPs from the The Million Mutation Project (Waterston/Moerman).
               The color of the SNP represents its potental effect on a gene. Green indicates a
	       possible missense; red a possible nonsense; blue a frameshift; yellow a 
	       disruption of a coding exon(s); and white for everything else.
&,
    };

    
    $features2config->{'RNAi_reagent:RNAi_primary'} = {
	track_name => 'RNAi_BEST',
	children   => ['experimental_result_region:cDNA_for_RNAi'],
	stanza => q&
feature       = RNAi_reagent:RNAi_primary experimental_result_region:cDNA_for_RNAi
key           = RNAi experiments (primary targets)
glyph         = segments
category      = Alleles, Variations, RNAi
bgcolor       = goldenrod
fgcolor       = black
height        = 4
label         = sub {
		my $f = shift;
		my $name   = $f->attributes('History_name');		
		my $string = $name ? $name : $f->name;
		return $string;
	}
description    = sub {
		my $f = shift;
		my $source = $f->attributes('Laboratory');
		my $string = $source ? "source lab: $source" : '';
		return $string;
	}
citation      = This track represents RNAi probes that have been aligned to the genome
                using a combination of BLAST and BLAT programs and have sequence identity
                to the target location of at least 95% over a stretch of at least 100 nt.
                Probes that satisfy these criteria are almost certain to produce RNAi
                effect on overlapping genes and the corresponding locations are usually
                the primary genomic targets of an RNAi experiment. Note that it is possible
                for a probe to have multiple primary targets within the genome. Click on the
                RNAi element to get more information about the experiment.
&,
    };

    $features2config->{'RNAi_reagent:RNAi_secondary'} = { 
	track_name => 'RNAi_OTHER',
	stanza => q&
feature       = RNAi_reagent:RNAi_secondary
key           = RNAi experiments (secondary targets)
category      = Alleles, Variations, RNAi
glyph         = segments
bgcolor       = red
fgcolor       = black
height        = 4
label         = sub {
		my $f = shift;
		my $name   = $f->attributes('History_name');		
		my $string = $name ? $name : $f->name;
		return $string;
	}
description    = sub {
		my $f = shift;
		my $source = $f->attributes('Laboratory');
		my $string = $source ? "source lab: $source" : '';
		return $string;
	}
citation      = This track represents RNAi probes that have been aligned to the genome 
                using BLAST program and have sequence identity to the target location 
                from 80 to 94.99% over a stretch of at least 200 nt. Probes that satisfy
                these criteria may or may not produce RNAi effect on overlapping genes
                and the corresponding locations represent possible secondary 
                (unintended) genomic targets of an RNAi experiment. Click on the RNAi 
                element to get more information about the experiment.
&,
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
	track_name => 'CURATED_BINDING_SITES',
	stanza => q^
# EG WBsf047547 III:7816962..7816982
key          = Binding sites (curated)
category     = Sequence Features:Binding Sites & Regions
feature      = binding_site:binding_site     
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;
		my ($name)   = $f->display_name;
		return "/get?name=$name;class=Feature";
	}
label       = 0
description  = 0
citation     = Sites where there is experimental evidence of a non-TF, non-Histone
               molecule binding.
^,
    };

    $features2config->{'binding_site:PicTar'} = {
	track_name => 'PREDICTED_BINDING_SITES',
	children   => ['binding_site:PicTar',
		       'binding_site:miRanda',
		       'binding_site:cisRed'],
	stanza => q^
key          = Binding sites (predicted)
category     = Sequence Features:Binding Sites & Regions
feature      = binding_site:PicTar
               binding_site:miRanda
               binding_site:cisRed
glyph        = box
bgcolor      = sub {
	my $f = shift;
	return 'blue' if $f->source eq 'PicTar';
	return 'red'  if $f->source eq 'miRanda';
	return 'green';
	}
link      = sub {
		my $f = shift;
		my %attributes  = $f->attributes();
		my ($note) = $attributes{Note};
		$note[0]  =~ /Predicted binding site for (.*)/;
		my $gene = $1;
		return "/get?name=$gene;class=Gene" if $gene;
		return "http://pictar.bio.nyu.edu/cgi-bin/new_PicTar_nematode.cgi?species=nematode" if $f->source eq 'PicTar';
		return "http://microrna.sanger.ac.uk/targets/v3/" if $f->source eq 'miRanda'; 
		return "/get?name=$name;class=Feature";
		return;
	}
label = sub {
	     my $f = shift;
	     my %attributes  = $f->attributes();
	     my ($note) = $attributes{Note};
	     return join("; ",@$note);
	     }
description = sub {
	    my $f = shift;
	    return $f->source;
           }
balloon hover = sub {
	        my $f    = shift;
		my $source = $f->source;		
		return "External data: See http://pictar.bio.nyu.edu/cgi-bin/new_PicTar_nematode.cgi?species=nematode" if $source eq 'PicTar';
		return "External data: See http://microrna.sanger.ac.uk/targets/v3/" if $source eq 'miRanda';				
		return;  # default to title
        }
citation     = This track shows curated and predicted binding sites for
               microRNAs. Binding sites (indicated in green) are extracted from the
               cisRed database of computationally derived potential bind
               targets. miRanda predictions -- indicated in red -- are the predicted
               target sequences for microRNA genes, provided by Anton Enright's group
               using the miRanda program. PicTar predictions -- indicated in blue --
               are the predicted target sequences for microRNA genes from Lall et al;
               A genome-wide map of conserved microRNA targets in C. elegans. Curr
               Biol. 2006 Mar 7;16(5):460-71.
^,
    };
    
    $features2config->{'binding_site:binding_site_region'} = {
	track_name => 'BINDING_REGIONS',
	stanza => q^
# EG: WBsf216878; III:7854473..7854493
key          = Binding regions
category     = Sequence Features:Binding Sites & Regions
feature      = binding_site:binding_site_region                    
glyph        = box
bgcolor      = green
link      = sub {
		my $f = shift;
		my $method = $f->method;
		my ($name)   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my ($name) = $f->name;
		return $name;
	}    
citation     = Regions within which there may be one or more binding sites of a
               non-TF, non-Histone molecule.
^,
    };

    $features2config->{'histone_binding_site:histone_binding_site_region'} = {
	track_name => 'HISTONE_BINDING_SITE_REGIONS',
	stanza => q^
# EG WBsf047038; III:7857561..7857581
key          = Histone binding sites
category     = Sequence Features:Binding Sites & Regions
feature      = histone_binding_site:histone_binding_site_region
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		return $name;
	}    
citation     = Regions within which there is experimental evidence for one or more
               binding sites of a histone.
^,
    };
	       
    $features2config->{'promoter:promoter'} = {
	track_name => 'PROMOTER_REGIONS',
	stanza => q^
# EG WBsf034281; I:5165237..5165257
key          = Promoter regions
category     = Sequence Features:Binding Sites & Regions
feature      = promoter:promoter
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		return $name;
	}    
citation     = Regions within which there is experimental evidence for a promoter.
^,
    };

    $features2config->{'regulatory_region:regulatory_region'} = {
	track_name => 'REGULATORY_REGIONS',
	stanza => q^
# EG WBsf047577; V:8387251..8387261
key          = Regulatory regions
category     = Sequence Features:Binding Sites & Regions
feature      = regulatory_region:regulatory_region
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		return $name;
	}    
citation     = Assorted or unspecified regulatory elements with experimental evidence.
^,
    };

    $features2config->{'TF_binding_site:TF_binding_site'} = {
	track_name => 'TRANSCRIPTION_FACTOR_BINDING_SITE',
	stanza => q^
# EG: WBsf047616, III:12550176..12550196
key           = Transcription factor binding sites
feature       = TF_binding_site:TF_binding_site
category     = Sequence Features:Binding Sites & Regions
glyph         = box
bgcolor       = green
fgcolor       = black
label         = sub {
	      my $f = shift;
	      my $name = $f->name;
	      return $name;
	      }
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
citation      = Sites where there is experimental evidence of a transcription factor
                binding site.
^,
    };

    $features2config->{'TF_binding_site:TF_binding_site_region'} = {
	track_name =>'TRANSCRIPTION_FACTOR_BINDING_REGION',
	stanza => q^
key           = Transcription factor binding regions
feature       = TF_binding_site:TF_binding_site_region
category      = Sequence Features:Binding Sites & Regions
glyph         = box
bgcolor       = green
fgcolor       = black
label         = sub {
	      my $f = shift;
	      my $name = $f->name;
	      return $name;
	      }
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
citation      = Regions within which there is experimental evidence of one or more
                binding sites of a transcription factor.
^		
    };

################################################
#
# Subcategory: Motifs
#
################################################

    $features2config->{'DNAseI_hypersensitive_site:DNAseI_hypersensitive_site'} = {
	track_name => 'DNAseI_HYPERSENSITIVE_SITE',
	stanza => q^
feature      = DNAseI_hypersensitive_site:DNAseI_hypersensitive_site
glyph        = box
category     = Sequence Features:Signals & Motifs
bgcolor      = green
key          = DNAseI hypersensitive site
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		my $notes  = $f->notes;
		$notes     = $name if ($notes eq '');
		return "$notes";
	}    
citation     = DNAse I hypersensitive sites from the 2009 paper by Shi et al.
^,
    };

    $features2config->{'G_quartet:pmid18538569'} = {
	track_name => 'G4_MOTIF',
	stanza => q^
feature       = G_quartet:pmid18538569
category      = Sequence Features:Signals & Motifs
bgcolor       = magenta
fgcolor       = black
height        = 7
connector     = none
key           = G4 Motif
citation      = This track shows the extent of G4 DNA signature. G4 motif is "Intrinsically mutagenic motif, probably
         because it can form secondary structures during DNA replication". Data are from Kruisselbrink E et al. (2008)
         Curr Biol "Mutagenic Capacity of Endogenous G4 DNA Underlies Genome Instability in ....".
^,
    };

################################################
#
# Subcategory: Translated Features
#
################################################

    $features2config->{'sequence_motif:translated_feature'} = {
	track_name => 'PROTEIN_MOTIFS',
	stanza => q^
# Individual spans
# feature     = motif_segment:translated_feature
# Single, full length spans
# feature     = Motif:translated_feature
# Aggregated features (skip top level feature)
#feature       = motif:translated_feature
feature       = sequence_motif:translated_feature
key           = Protein motifs
category      = Sequence Features:Translated Features
glyph         = segments
connector     = dashed
connector_color = gray
fgcolor       = black
bgcolor       = sub {
		my $feature = shift;
		my $name = $feature->name;
                return 'magenta'          if ($name =~ /tmhmm/);
                return 'lightseagreen'     if ($name =~ /seg/);
	        return 'aquamarine'    if ($name =~ /signalp/);
       		return 'chartreuse'    if ($name =~ /ncoils/);
		return 'lightsalmon'         if ($name =~ /pfam/);
	}
#link          = sub { my $f   = shift;
#     		my %notes = map { split /=/ } $f->notes;
#                #my $name = $f->name;
#                #my ($target) = $name =~ /(WP_.*)\-.*/;
#		#$target =~ s/_/:/g;
#                return "/get?name=$notes{Protein};class=Protein";
#        }
height        = 7
#label         = sub { 
#		my $f = shift;
#		my $name = $f->name;
#		#my ($label) = $name =~ /(WP_.*-.*)\.\d/;
#                #my ($label) = $name =~ /(.*)\-.*\.\d$/;
#		#$label =~ s/_/:/;
#		my %notes = map { split /=/ } $f->notes;
#		my $label = $notes{Type};
#		return $label;
#	}
#description = sub { my $feature = shift;
#		my %notes = map { split /=/ } $feature->notes;
##		my $desc = "$notes{CDS}; aa: $notes{Range}; exon(s): $notes{Exons}";
##		$desc .= "; $notes{Description}" if $notes{Description};
##		my $desc = $notes{Type};
##		$desc .= "; $notes{Description}" if $notes{Description};
#		my $desc = $notes{Description};
#		return $desc;
#	}
citation      = This track shows the extent of predicted protein motifs. Note these
                spans correspond to amino acid coordinates interpolated onto the
                physical map.  Included are signal peptide (signalp), coiled coil (ncoils)
		and transmembrane (tmhmm) domains, regions of low complexity (seg),
                and Pfam annotated motif homologies. 
^,
    };
    
    $features2config->{'translated_nucleotide_match:mass_spec_genome'} = {
	track_name => 'MASS_SPEC',
	stanza => q&
# Individual spans
feature      = translated_nucleotide_match:mass_spec_genome
key           = Mass spec peptides
category      = Sequence Features: Translated Features
glyph         = segments
draw_target   = 1
show_mismatch = 1
ragged_start  = 1
connector     = dashed
connector_color = gray
fgcolor       = black
bgcolor       = sub {
		my $feature = shift;
		my $name = $feature->name;
		return 'red';
	}
link          = sub { my $f   = shift;
                my $name = $f->name;
                return "/get?name=$name;class=Mass_spec_peptide";
        }
height        = 7
label         = sub { 
		my $f = shift;
		my $name = $f->name;
		$name =~ s/^MSP://;
		return $name;
	}
#group_pattern = /^Mass_spec_peptide:[.*]/
description  = sub { return undef; }
#description = sub { 
#		my $f = shift;
#		my $exons = $f->attributes('Exons_covered');
#		return $exons;
#}
#title   = sub {
#		my $f = shift;
#		return $f->attributes('Exons_covered');
#	}
citation      = This track shows peptides identified in mass spec proteomics
                experiments.
&,
    };


################################################
#
# Category: Expression
#
################################################

    $features2config->{'SAGE_tag:SAGE_tag'} = {		  
	track_name => 'SAGE',
	stanza => q^
key           = SAGE tags
category      = Expression
feature       = SAGE_tag:SAGE_tag
glyph	      = transcript2
arrow_length  = 2
orient        = sub {
	          my $f = shift;
		  return $f->strand > 0 ? 'E' : 'W';
                }
strand_arrow  = 1
height        = 7
description   = sub {
		  my $f = shift;
		  return 0 if $f->source eq 'SAGE_tag';
		  my $name = $f->name;
		  $name =~ s/SAGE://;
	  	  return $name;
	  	}
bgcolor       = sub {
                  my $f = shift;
		  return 'lightgrey' if $f->source eq 'SAGE_tag';                
		  return $f->strand > 0 ? 'violet' : 'turquoise';
	       }
fgcolor       = sub {
                  my $f = shift;
                  return 'lightgrey' if $f->source eq 'SAGE_tag';
                  return $f->strand > 0 ? 'violet' : 'turquoise';
               }
label         = sub {
		  my $f = shift;
	          return '' if $f->source eq 'SAGE_tag';
		  my ($cnt)  = $f->attributes('count');
	          my ($gene) = $f->attributes('Gene', 'Transcript', 'Pseudogene');
		  return "$gene count:$cnt" if $gene && $cnt; 
  		}
link          = sub {
                  my $f = shift;
	          my $name = $f->name;
	          return "/db/seq/sage?name=$name;class=SAGE_tag";
               }
citation      = This track indicates the location of Serial Analysis of Gene Expression (SAGE)
        patterns associated with a tag and its associated genes.  Tags shown in grey are
	either unambiguously mapped to a gene elsewhere or are ambigous due to multiple occurences
	in genomic or trascript sequences.  Colored tags are mapped unambiguously to a single
        gene or genomic location.  Violet and turquoise refer to the plus strand and minus 
        strands, respectively.  The number shown above tags is the total number of times
        this tag was observed in all SAGE experiments.

[SAGE:7001]
arrow_length  = 3
    
[SAGE:10001]
arrow_length  = 5
label         = sub {
                  my $f = shift;
                  return 0 if $f->source eq 'SAGE_tag';
                  my ($cnt) = $f->attributes('count');
		  return "$cnt "; #must not be '1'
                }
^,
};

$features2config->{'experimental_result_region:Expr_profile'} = {
track_name => 'EXPRESSION_CHIP_PROFILE',
stanza => q^
feature       = experimental_result_region:Expr_profile
category      = Expression
bgcolor       = orange
fgcolor       = black
height        = 4
key           = Expression chip profiles
citation      = This track indicates the location of PCR products that have been placed on
	expression chips produced by the C. elegans Microarray Consortium [
	<a href="http://cmgm.stanford.edu/~kimlab/wmdirectorybig.html">http://cmgm.stanford.edu/~kimlab/wmdirectorybig.html</a>]. 
	The genes corresponding to these products have been clustered by their
	expression patterns.  Click on the profile to get more information about the expression
	profile of its corresponding gene.
^,
};

$features2config->{'reagent:Expr_pattern'} = {
track_name => 'EXPRESSION_PATTERNS',
stanza => q^
key           = Expression patterns
category      = Expression
feature       = reagent:Expr_pattern
glyph         = sub {
		  my $name = shift->name;
		  my $png = -e "/usr/local/wormbase/website-shared-files/images/expression/assembled/$name.png";
	          return $png ? 'image' : 'span';
                }
glyph_delegate = span
image         = sub {
                  my $f = shift;
                  my $flip = $f->strand > 0 ? ';flip=1' : '';
                  my $name = $f->name;	
                  "/db/gene/expression?name=$name;draw=1;thumb=250$flip";
                }
link          = /get?name=$name;class=Expr_pattern
balloon hover = sub {
	          my $name   = shift->name;
		  my $length = shift->length;
		  my $png = -e "/usr/local/wormbase/website-shared-files/images/expression/assembled/$name.png";
                  my $cartoon = $length > 99999 && $png ? ';cartoon=1' : '';
		  "url:/gbrowse_popup?name=$name;type=EXPR_PATTERN$cartoon";
		}
bgcolor       = silver
fgcolor       = black
height        = 8
fontcolor     = blue
label         = sub {
                  my $f = shift;
#                  my $ace = ElegansSubs::OpenDatabase();
#                  my $obj = $ace->fetch($f->class => $f->name);
#                  my ($gene) = ElegansSubs::Bestname($obj->Gene);
#                  my ($construct) = $obj->Transgene;
#                  $gene .= " ($construct)" if $construct;
#                  $gene;
                }
citation      = This track represents sequences that were used for in vivo expression pattern analysis,
                such as promoter sequences for GFP or LacZ constructs.  Colored areas in the worm
                image represent approximate regions where adult or late larval expression has been
                documented via Anatomy Ontology terms.  The strand of the sequence (promoter) region
                used is indicated by color in the same way as genes, where violet is the forward
                strand and turqoise is the reverse strand.  Clicking on the worm image will take you
                to a detailed view of the expression pattern.


[EXPR_PATTERN:40000]
image         = sub {"/db/gene/expression?draw=1;thumb=225;name=".shift->name}
[EXPR_PATTERN:60000]
image         = sub {"/db/gene/expression?draw=1;thumb=200;name=".shift->name}
[EXPR_PATTERN:80000]
image         = sub {"/db/gene/expression?draw=1;thumb=175;name=".shift->name}
[EXPR_PATTERN:100000]
glyph         = span
^,
};

$features2config->{'transcript_regions:RNASeq_reads'} = {
track_name => 'RNASEQ',
stanza => q^
key          = RNASeq
feature      = transcript_regions:RNASeq_reads
glyph        = box
category     = Expression
bgcolor      = black
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
height    = sub { 
	  my $f = shift;
	  my $score = $f->score;
	  # range of 1-100
	  my $height = int($score / 2);
      	  $height = 50 if ($score > 100);
	  $height = ($height == 0 || $height == 1) ? 2 : $height;
	  return $height;
	  }
bump = 0
label     = sub {
          my $f = shift;
	  my $score = $f->score;
	  return "Score: $score";
	}    
citation    =  These boxes indicate alignments of short read sequences from all available RNASeq
               projects. The number of reads has been normalised by averaging over
               the number of libraries. The height of all boxes indicates the relative score of
               the feature.
^,
};

$features2config->{'intron:RNASeq_splice'} = {
track_name => 'RNASEQ_SPLICE',
stanza     => q^
key          = RNASeq introns
category     = Expression
feature      = intron:RNASeq_splice
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
height    = sub { 
	  my $f = shift;
	  my $score = $f->score;
	  # range of 1-100
	  my $height = int($score / 2);
	  $height = 50 if ($score > 100);
	  $height = ($height == 0 || $height == 1) ? 2 : $height;
	  return $height;
	  }
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		return $name;
	}    
title     = sub {
		my $f = shift;
		my $name   = $f->name;
		my $notes  = $f->notes;
		$notes     = $name if ($notes eq '');
		return "$notes";
	}    
citation    = These are introns formed by aligned RNASeq reads spanning a
	      region of the genome. Alignments of short read sequences from
	      all available RNASeq projects were used. The number of reads
	      spanning the introns is indicated by the thickness of the display.
^,
};

$features2config->{'transcript_region:RNASeq_F_asymmetry'} = {
track_name => 'RNASEQ_ASYMMETRIES',
children   => ['transcript_region:RNASeq_R_asymmetry'],
stanza     => q^
key          = RNASeq Asymmetries
category     = Expression
feature      = transcript_region:RNASeq_F_asymmetry
	       transcript_region:RNASeq_R_asymmetry
glyph        = box
bgcolor      = sub {
	     my $f = shift;
	     my $method = $f->method;
	     return 'red' if $method eq 'RNASeq_R_asymmetry';
	     return 'green' if $method eq 'RNASeq_F_asymmetry';
	     return 'black';
	     }	     

link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
height    = sub { 
	  my $f = shift;
	  my $score = $f->score;
	  # range of 1-1000
          my $height = int($score / 20);
     	  $height = 50 if ($score > 1000);                 
	  $height = ($height == 0 || $height == 1) ? 2 : $height;
	  return $height;
	  }
bump = 0
label     = sub {
		my $f = shift;
	        my $score = $f->score;
    	        return "Score: $score";
	}    
citation    =  Red boxes indicate regions where there are more than 2 times as many
               forward sense RNASeq reads aligned to the genome as reverse sense
               reads. This asymmetrical signal has been found empirically to be a
               sensitive marker for the ends of transcripts.
               Green boxes indicate regions where there are more than 2 times as many
               reverse sense RNASeq reads aligned to the genome as forward sense
               reads. This asymmetrical signal has been found empirically to be 
               sensitive marker for the ends of transcripts.
               The height of all boxes indicates the relative score of the feature.
    ^,
};

$features2config->{'mRNA_region:Polysome_profiling'} = {
track_name => 'POLYSOMES',
stanza => q^
key          = Polysomes
category     = Expression
feature      = mRNA_region:Polysome_profiling
glyph        = box
bgcolor      = green
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		my $notes  = $f->notes;
		$notes     = $name if ($notes eq '');
		return "$notes";
	}    
citation     = This data is from the The Lamm et al. (2011) PMID: 21177965 paper
               finding regions bound by the polysome fraction of RNAs being actively
               translated.
^,
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
track_name => 'GENOME_SEQUENCE_ERRORS',
stanza => q^
# EG: WBsf267823, III: 13536936
key           = Genome sequence errors
feature       = possible_base_call_error:RNASeq
category      = Genome Structure:Assembly & Curation
glyph         = box
bgcolor       = red
fgcolor       = black
label         = sub {
	      my $f = shift;	      
	      my $name = $f->name;
	      return $f->name;
	      }
citation      = Positions within the reference genome sequence that have been
                identified as having a base call error. This error has not yet been
                corrected.
^,
};

$features2config->{'base_call_error_correction:RNASeq'} = {
track_name => 'CORRECTED_GENOME_SEQUENCE_ERRORS',
stanza => q^
# EG: WBsf047679; III:10553079..10553089
key           = Genome sequence corrections
feature       = base_call_error_correction:RNASeq
category      = Genome Structure:Assembly & Curation
glyph         = box
bgcolor       = green
fgcolor       = black
label         = sub {
	      my $f = shift;	      
	      my $name = $f->name;
	      return $f->name;
	      }
citation      = Positions within the reference genome sequence that were previously
                identified as having a base call error. This error has now been
                corrected.
^,
};

$features2config->{'assembly_component:Genomic_canonical'} = {
track_name => 'LINKS_AND_SUPERLINKS',
children   => ['assembly_component:Link'],
stanza     => q^
key           = Links and Superlinks
category      = Genome Structure:Assembly & Curation
feature       = assembly_component:Genomic_canonical assembly_component:Link
fgcolor       = black
glyph         = arrow
das category  = structural
height        = 7
tick          = 2
relative_coords = 1
citation      = This track shows the location and coordinates of contigs
	        created during the assembly of the C. elegans genome.
^,
};

$features2config->{'assembly_component:Genbank'} = {
track_name => 'GENBANK',
stanza    => q^
feature       = assembly_component:Genbank
glyph         = arrow
key           = Genbank submissions
category      = Genome Structure:Assembly & Curation
tick          = +2
base          = 1
relative_coords = 1
fgcolor       = sienna
link          = http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?cmd=Search&db=Nucleotide&doptcmdl=GenBank&term=$name[accn]
# link          = ../gbrowse_moby?id=$name;source=$class
citation      = The C. elegans genome was submitted to the GenBank and EMBL databases in
     	        in the form of a set of minimally-overlapping segments.  This track shows the
	        position of these accessioned entries.
^,
};

$features2config->{'assembly_component:Genomic_canonical'} = {
track_name => 'CANONICAL',
stanza => q^
feature       = assembly_component:Genomic_canonical
fgcolor       = sienna
glyph         = arrow
das category  = similarity
category      = Genome Structure:Assembly & Curation
label         = sub {
		my $f = shift;
		my $note = $f->attributes('Note');
	        my ($gb) = $note =~ /Genbank\s+(\S+)/;
		my $retval = $f->name;
		$retval .= " (Genbank $gb)" if $gb;
               }
height        = 7
tick          = 2
relative_coords = 1
key           = Contig submissions
citation      = This track shows the location and coordinates of contigs
        (mostly cosmids) submitted to GenBank/EMBL.
link          = sub {
                my $f = shift;
                my $note = $f->attributes('Note');
                my ($gb) = $note =~ /Genbank\s+(\S+)/;
                $gb || return undef;
		"http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?cmd=Search&db=Nucleotide&doptcmdl=GenBank&term=${gb}[accn]";
                }
^,
};

$features2config->{'duplication:segmental_duplication'} = {
track_name => 'SEGMENTAL_DUPLICATIONS',
stanza => q^
feature       = duplication:segmental_duplication
category      = Genome Structure
glyph         = box
bgcolor       = white
fgcolor       = black
label         = sub {
	      my $f = shift;
	      return $f->notes || $f;
	      }
key           = Segmental duplication
citation      = Polymorphic segmental duplication as defined by the tool OrthoCluster. This feature represents one sequence from a pair of duplicons in the N2 genome.
^,
};



################################################
#
# Subcategory: Repeats
#
################################################

$features2config->{'low_complexity_region:dust'} = {
track_name => 'REPEATS_DUST',
stanza     => q^
feature       = low_complexity_region:dust
bgcolor       = bisque
fgcolor       = black
category      = Genome Structure:Repeats
height        = 4
key           = Low complextity region (Dust)
connector     = none
description   = sub {
	my $f = shift;
	my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
	my $method = $f->method;
	$method =~ s/_/ /g;
	return join('; ',$f->notes,"$ref: $start..$stop");
	}
label         = sub {
	my $f = shift;
	my $method = $f->method;
	$method =~ s/_/ /g;
	return $method;
	}
link          = 0
citation      = Low-complexity regions identified by Dust.
^,
};

$features2config->{'repeat_region:RepeatMasker'} = {
track_name => 'REPEATS_REPEAT_MASKER',
stanza     => q^
feature       = repeat_region:RepeatMasker
bgcolor       = bisque
fgcolor       = black
category      = Genome Structure:Repeats
height        = 4
key           = Repeat Region (RepeatMasker)
connector     = none
description   = sub {
	my $f = shift;
	my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
	my $method = $f->method;
	$method =~ s/_/ /g;
	return join('; ',$f->notes,"$ref: $start..$stop");
	}
label         = sub {
        my $f = shift;
        my $label = $f->id;
        $label=~s/Motif://;
	return $label;
	}
link          = 0
citation      = Repetitive regions identified by RepeatMasker.
^,
};

$features2config->{'inverted_repeat:inverted'} = {
track_name => 'REPEATS_TANDEM_AND_INVERTED',
children   => ['tandem_repeat:tandem'],
stanza     => q^
feature       = inverted_repeat:inverted
	        tandem_repeat:tandem	        
bgcolor       = bisque
fgcolor       = black
category      = Genome Structure:Repeats
height        = 4
key           = Tandem and Inverted Repeats (TRF and inverted)
connector     = none
description   = sub {
	my $f = shift;
	my ($ref,$start,$stop) = ($f->ref,$f->start,$f->stop);
	my $method = $f->method;
	$method =~ s/_/ /g;
	return join('; ',$f->notes,"$ref: $start..$stop");
	}
label         = sub {
	my $f = shift;
	my $method = $f->method;
	$method =~ s/_/ /g;
	return $method;
	}
link          = 0
citation      = Exact tandem and inverted repetitive elements.
^,
};


################################################
#
# Category: Transcription
#
################################################

$features2config->{'expressed_sequence_match:BLAT_EST_BEST'} = {
track_name => 'EST_BEST',
stanza => q^
key            = ESTs (best)
category       = Transcription:Products
feature        = expressed_sequence_match:BLAT_EST_BEST
glyph          = segments
das category   = transcription
draw_target    = 1
show_mismatch  = 1
ragged_start   = 1
height         = 5
bgcolor        = limegreen
fgcolor        = black
mismatch_color = yellow
connector      = solid
group_pattern  = /\.[35]$/
citation       = Native (same-species) Expressed Sequence Tags (ESTs), aligned to
                 the genome using <a href="http://genome.cse.ucsc.edu/cgi-bin/hgBlat">BLAT</a>.
                 This track shows the best unique location for each EST. Other EST matches, some
                 of which may represent repetitive elements, are shown in the track labeled
                 "ESTs (other)". The paired 5' and 3' ESTs from the same cDNA clone 
                 are connected by a dashed line.

[EST_BEST:50000]
glyph = box
^,
};

$features2config->{'expressed_sequence_match:BLAT_EST_OTHER'} = {
track_name => 'EST_OTHER',
stanza     => q^
key           = ESTs (other)
category      = Transcription:Products
feature       = expressed_sequence_match:BLAT_EST_OTHER
glyph         = segments
draw_target   = 1
show_mismach  = 1
ragged_start  = 1
bgcolor       = lightgray
fgcolor       = black
height        = 6
connector     = solid
group_pattern = /\.[35]$/
citation      = Native (same-species) Expressed Sequence Tags (ESTs), aligned to the genome 
                using <a href="http://genome.cse.ucsc.edu/cgi-bin/hgBlat">BLAT</a>.
                This track shows ESTs that align multiple times, some of which represent 
                repetitive regions. For the "best" match, see the track labeled "ESTs (best)".  
                The paired 5' and 3' ESTs from the same cDNA clone are connected 
                by a dashed line.

[EST_OTHER:50000]
glyph = box
^,
};

$features2config->{'expressed_sequence_match:BLAT_mRNA_BEST'} = {
track_name => 'mRNA_BEST',
children   => ['expressed_sequence_match:BLAT_ncRNA_BEST'],
stanza     => q^
key        = mRNAs/ncRNAs (best)
category   = Transcription:Products
feature    = expressed_sequence_match:BLAT_mRNA_BEST 
             expressed_sequence_match:BLAT_ncRNA_BEST
glyph = segments
label = sub {
    my $f = shift;
    my $label = ($f->source =~ /BLAT_mRNA_BEST/) ? 'mRNA' : 'ncRNA';
    my $name = $f->name;
    return "$label: $name";
  }
draw_target  = 0
show_mismach = 1
ragged_start = 1
bgcolor = sub {
    my $f = shift;
    return 'yellow' if ($f->source =~ /BLAT_mRNA_BEST/);
    return 'grey';
  }
fgcolor   = black
height    = 6
connector = solid
citation  = Native (same species) full length cDNAs and ncRNAs aligned to
            the genome using <a href="http://genome.cse.ucsc.edu/cgi-bin/hgBlat">BLAT</a>.
            This track shows the best unique location for each cDNA. Other cDNA matches, some
            of which may represent repetitive elements, are shown in the track labeled
            "mRNAs/ncRNAs (other)".

[mRNA_BEST:5000]
glyph = box
^,
};

$features2config->{'alignment:BLAT_ncRNA_OTHER'} = {
track_name => 'mRNA_OTHER',
children => ['alignment:BLAT_mRNA_OTHER'],
stanza => q^
key      = mRNAs/ncRNAs (other)
category = Transcription:Products
feature  = alignment:BLAT_mRNA_OTHER alignment:BLAT_ncRNA_OTHER
glyph    = segments
label    = sub {
    my $f = shift;
    my $label = ($f->source =~ /BLAT_mRNA_OTHER/) ? 'mRNA' : 'ncRNA';
    my $name = $f->name;
    return "$label: $name";
  }
draw_target  = 1
show_mismach = 1
ragged_start = 1
bgcolor = sub {
    my $f = shift;
    return 'green' if ($f->source =~ /BLAT_mRNA_OTHER/);
    return 'grey';
  }
fgcolor   = black
height    = 5
connector = solid
citation  = Native (same species) full length mRNAs and ncRNAs aligned to the 
            genome using <a href="http://genome.cse.ucsc.edu/cgi-bin/hgBlat">BLAT/a>.
            This track shows non-unique matches, which may represent repetitive sequences.
            For the best single alignment, see the track labeled "mRNAs/ncRNAs (best)".

[mRNA_OTHER:5000]
glyph = box
^,
};

$features2config->{'TSS:RNASeq'} = {
track_name => 'TRANSCRIPTION_START_SITE',
stanza => q^
feature       = TSS:RNASeq
category      = Transcription:Signals
glyph         = box
bgcolor       = white
fgcolor       = black
label         = sub {
	      my $f = shift;
	      return $f->notes || $f;
	      }
key           = Transcription start site
citation      = Transcription_start_site defined by analysis of RNASeq short read datasets (example Hillier et al.)
^,
};

$features2config->{'transcription_end_site:RNASeq'} = {
track_name => 'TRANSCRIPTION_END_SITE',
stanza => q^
feature       = transcription_end_site:RNASeq
category      = Transcription:Signals
glyph         = box
bgcolor       = white
fgcolor       = black
label         = sub {
	      my $f = shift;
	      return $f->notes || $f;
	      }
key           = Transcription end site
citation      = Transcription_end_site defined by analysis of RNASeq short read datasets (example Hillier et al.)
^,
};

$features2config->{'nucleotide_match:TEC_RED'} = {
track_name => 'TECRED_TAGS',
stanza     => q^
feature  = nucleotide_match:TEC_RED
glyph    = box
bgcolor  = red
category = Transcription:Supporting Evidence
height   = 5
key      = TEC-RED tags
citation = Trans-spliced Exon Coupled RNA End Determination (TEC-RED) tags. TEC-RED uses a method similar to SAGE
	   to identify expressed genes and characterize the 5' end of transcripts.
^,
};

$features2config->{'five_prime_open_reading_frame:micro_ORF'} = {
track_name => 'MICRO_ORF',
stanza => q^
feature      = five_prime_open_reading_frame:micro_ORF
glyph        = box
category     = Transcription:Supporting Evidence
bgcolor      = green
key          = Micro ORF
link         = sub {
		my $f = shift;		
		my $name   = $f->name;
		return "/get?name=$name;class=Feature";
	}
label     = sub {
		my $f = shift;
		my $name   = $f->name;
		my $notes  = $f->notes;
		$notes     = $name if ($notes eq '');
		return "$notes";
	}    
citation     = The location of micro ORFs with experimental evidence.
^,
};

$features2config->{'PCR_product:Orfeome'} = {
track_name => 'ORFEOME_PCR_PRODUCTS',
stanza => q^
key           = ORFeome PCR Products
category      = Transcription:Supporting Evidence
feature       = PCR_product:Orfeome
glyph         = sub {
		my $f = shift;
		return 'primers' if $f->method eq 'PCR_product';
		return 'box';
	}	
height        = 4
fgcolor       = black
connect       = 1
#connect_color = \&ostp_color
#font2color    = \&ostp_color
#fgcolor       = \&ostp_color
#description   = \&ostp_amplifies
citation      = This track contains Orfeome Project primer pairs and RACE tags.  These primers were used to amplify
	C. elegans cDNAs.  A positive amplification, shown in green, is evidence that the region
	between the two primers is transcribed.  Failure to amplify, shown in red, suggests
	either that the gene model is incorrect, or that the gene is expressed at very low levels.
	Detailed gene models derived from ORFeome sequencing will be added to this display in
	the future.  See <i>Reboul et al. Nat. Genet. 2003 Apr 7.</i> and 
	<a href="http://worfdb.dfci.harvard.edu" target="_blank">WORFdb</a> for further information.
^,
};

$features2config->{'transcribed_fragment:TranscriptionallyActiveRegion'} = {
track_name => 'TRANSCRIPTION_FACTOR_BINDING_REGION',
stanza     => q^
feature       = transcribed_fragment:TranscriptionallyActiveRegion
category      = Transcription:Supporting Evidence
glyph         = box
bgcolor       = green
fgcolor       = black
label         = sub {
	      my $f = shift;
	      my $name = $f->name;
	      my $notes = $f->notes;
	      return "$notes";
	      }
key           = Transcriptionally Active Region
citation      = Transcriptionally Active Regions (TARs) found by the Miller lab from tiling-array projects run as part of the modENCODE project.
^,
};


$features2config->{'expressed_sequence_match:BLAT_OST_BEST'} = {
track_name => 'OST',
stanza     => q%
key           = C.elegans OSTs
category      = Transcription:Supporting Evidence
feature       = expressed_sequence_match:BLAT_OST_BEST
glyph         = segments
draw_target   = 1
show_mismatch = 1
ragged_start  = 1
height        = 5
fgcolor       = black
connector     = solid
group_pattern = /^OST[RF]/
description   = OST
link = sub {
    my $feature = shift;
    my $name = $feature->name;
    $name =~ s/^OST[FR](10|30)/$1/;
    $name =~ s/^OST[FR]/10/;
    $name =~ s/_\d*//;
    $name =~ s/([A-Z]+\d+)$/\@$1/;
    return qq[http://worfdb.dfci.harvard.edu/searchallwormorfs.pl?by=plate&sid=$name];
  }
label       = 1
link_target = _blank
citation    = <a href="http://worfdb.dfci.harvard.edu/">ORFeome project</a> sequence reads.
              The ORFeome project designs primer assays for spliced C. elegans mRNAs and then performs 
              sequence reads on rtPCR material, producing "OSTs." This track shows ORFeome project 
              OSTs aligned to the genome using 
              <a href="http://genome.cse.ucsc.edu/cgi-bin/hgBlat">BLAT</a>. This track shows the 
              best unique location for each OST.
%,
};

$features2config->{'expressed_sequence_match:BLAT_RST_BEST'} = {
track_name => 'RST',
stanza     => q\
key           = C.elegans RSTs
category      = Transcription:Supporting Evidence
feature       = expressed_sequence_match:BLAT_RST_BEST
glyph         = segments
strand_arrow  = 1
draw_target   = 1
show_mismatch = 1
ragged_start  = 1
height        = 5
fgcolor       = black
bgcolor       = sub {
    my $f = shift;
    return 'green' if $f->name =~ /RST5/;
    return 'red';
  }
connector     = solid
group_pattern = /^OST[RF]/
label         = 1
description   = sub {
    my $f = shift;
    return "5' RST" if $f->name =~ /RST5/;
    return "3' RST" if $f->name =~ /RST3/;
  }
citation = The submitted RACE data come from cloning and sequencing of 5' and 3' C.elegans RACE 
           PCR products. The experiments were done using RNA isolated from "mix stage"
           wild-type N2 worms. SL1 and SL2 were used as 5' universal primers for 5'RACE
           experiments. The "RST's" (i.e., RACE Sequence Tags), are 5' reads from cloned RACE 
           products (sequenced as minipools). Sequences are vector trimmed then quality trimmed 
           (SL sequences are not removed from 5' RST's). In quality trimming, the first sliding
           window of 20 nt long with an average quality score higher than 15 marks the
           start of good quality sequences. Likewise, the first sliding window of 20 nt
           with average quality score lower than 15 marks the end of good quality
           sequences.

           Each RST is identified as being 5' or 3'(indicated as 5-RST or 3-RST) followed
           by a unique trace ID (e.g., >CCSB_5-RST_373657). 1,355 5' and 1589 3' RSTs are
           included in this submission. Data provided by Kourosh Salehi-Ashtiani, Vidal Lab.

           For information on the project, please see the
           <a href="http://worfdb.dfci.harvard.edu/index.php?page=race">Race Project Page</a>
           at <a href="http://worfdb.dfci.harvard.edu/">WorfDB</a>.
\,
};


################################################
#
# Category: Sequence similarity
#
################################################

################################################
#
# Subcategory: nucleotide
#
################################################

   
    return $features2config;
}




sub species_config {
    my $self = shift;
    my $species_config = {
	c_elegans_PRJNA13758 => {
	    stanzas => {
		general => {
		    examples           => 'IV IV:20,000..40,000 lin-29 dpy-* rhodopsin B0019 PCR_product:sjjB0019.1 ttattaaacaatttaa',
		    'default tracks'   => 'PRIMARY_GENE_TRACK CLASSICAL_ALLELES POLYMORPHISMS LOCI:overview',
		    link               => '/get?name=$name;class=$class',
		    'initial landmark' => 'III:9060076..9071672',
		    description        => 'C. elegans (current release)',
		    database           => 'c_elegans',
		},
		'this_database:database'   => {
		    db_args => q^
    -adaptor DBI::mysql
    -dsn dbi:mysql:database=c_elegans_PRJNA13758_WS240;host=mysql.wormbase.org
    -user wormbase
    -pass sea3l3ganz
^,
		},
    
    primary_gene_track => {
	key => 'Curated Genes',
	citation => q^
           Protein-coding gene structures result from the integration of a variety 
           of prediction methods and data sources followed by manual review and revison 
           by WormBase curators. tRNAs are predicted by tRNAscan, and other non-coding 
           RNA transcripts are taken from a variety of literature sources. 
           The purple and blue colors indicate transcripts on the forward and 
           reverse strands respectively. If sufficient room is available between 
           features, gene models end with a triangle; if not a small arrow is used. 
           Grey areas represent 5' and 3' UTRs of protein-coding transcripts, assigned  
           automatically using the extents of overlapping ESTs and full-length cDNAs. The 
           UTR predictions have not been reviewed by WormBase curators, and some are 
           known to contain artifacts.
^,
},
	   polymorphisms => {
	       citation => q^
               This track shows single nucleotide polymorphisms (SNPs).
               In this track, the molecular nature of the polymorphism is indicated by
               its glyph: Boxes are deletions; triangles are insertions; point mutations
               and substitutions are diamonds. Color reflects the source strain: polymorphisms 
	       found in CB4858 (Pasadena) are shown in blue; those found in CB4856 (Hawaii) in yellow,	
	       and all others in white.
^,
       },
	    },
	       extra_stanzas => 
	   q^


[TODDTEST]
#include /usr/local/wormbase/website/tharris/conf/gbrowse/includes/operons.track

[DETAIL SELECT MENU]
# C. elegans has a custom detail menu. Over-ride the default here.
width = 260
html  = <table style="width:100%">
         <tr>
           <th style="background:lightsteelblue;cell-padding:5">
             SELECTION
             <span style="right:0px;position:absolute;color:blue;cursor:pointer"
                   onclick="SelectArea.prototype.cancelRubber()">
               [X]
             </span>
           </th>
         </tr>
         <tr>
           <td>
             <a href="javascript:SelectArea.prototype.clearAndSubmit()">
              Zoom in
             </a>
           </td>
         </tr>
        <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="?plugin=FastaDumper;plugin_action=Go;name=SELECTION" target="_new">
              Dump selection as FASTA
             </a>
           </td>
         </tr>
         <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="http://modencode.oicr.on.ca/cgi-bin/gb2/gbrowse/worm/?name=SELECTION" target="_new">
               Browse selection at modENCODE
             </a>
           </td>
         </tr>
         <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="http://genome.ucsc.edu/cgi-bin/hgTracks?clade=worm&org=C.+elegans&db=ce4&position=chrSELECTION&pix=620&Submit=submit" target="_new">
               Browse selection at UCSC
             </a>
           </td>
         </tr>
         <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="?name=SELECTION;plugin=Submitter;plugin_do=Go;Submitter.target=UCSC_BLAT" target="_new">
               BLAT this sequence
             </a>
           </td>
         </tr>
         <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="?name=SELECTION;plugin=Submitter;plugin_do=Go;Submitter.target=NCBI_BLAST" target="_new">
               BLAST this sequence
             </a>
           </td>
         </tr>
       </table>

[MotifFinder:plugin]
matrix = matrices.txt

[Aligner:plugin]
# THESE TRACK NAMES NEED TO BE UPDATES
alignable_tracks   = ESTB ESTO mRNAB
upcase_tracks      = CDS tRNA NG
align_default      = ESTB
upcase_default     = CDS
#ragged_default     = 10

[OligoFinder:plugin]
search_segments = I II III IV V X

[LOCI:overview]
key           = Landmarks
feature       = gene:landmark
label         = sub {
		my \$f = shift;
		return join(", ", \$f->get_tag_values('Locus'));
	}
glyph         = generic
bgcolor       = lavender
height        = 5

#[modencode_henikoff:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_henikoff;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = default +wildcard -stem +fulltext +autocomplete

#[modencode_hillier_genelets:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_hillier_genelets;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
##search options = exact
#search options = default +wildcard -stem +fulltext +autocomplete

#[modencode_hillier_itranscripts:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_hillier_itranscripts;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = exact

#[modencode_lieb:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_lieb;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = exact

#[modencode_piano:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_piano;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = exact

#[modencode_snyder:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_snyder;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = exact

#[modencode_waterston:database]
#db_adaptor    = Bio::DB::SeqFeature::Store
#db_args       = -dsn dbi:mysql:database=modencode_waterston;host=mysql.wormbase.org
#	        -user wormbase
#	        -pass sea3l3ganz
#search options = exact
    
# GBrowse Cliff notes:
# title - shown on hover
# label - shown ABOVE feature
# description - shown BELOW feature; can NOT reside in an include file
# Things like bgcolor:
#       bgcolor is applied per COMPONENT, not in aggregate.
    
^,
},
    };
    return $species_config;
}




1;

