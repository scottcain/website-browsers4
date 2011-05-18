	# Pack database
#	$self->pack_database();
#	
#	my $target_db = $self->db_symbolic_name;
# We will update symlinks when we go live
#	# $self->update_symlink({path => $self->mysql_data_dir,
#	# 		       target  => $target_db,
#	# 			   symlink => $species, # assumes config files are up-to-date as g_species -> g_species_release!
#	# 			   });
#	
#	my $custom_gff  = $self->get_filename('genomic_gff2_archive',$species);
#	$self->update_symlink({path    => join("/",
#	 					       $self->ftp_root,
#	 					       $self->local_ftp_path,
#	 					       "genomes/$species/genome_feature_tables/GFF2"),
#	 			       target  => "$gff",
#	 			       symlink => 'current.gff2.gz',
#	 			   });
