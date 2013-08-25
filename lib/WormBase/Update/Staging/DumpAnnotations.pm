package WormBase::Update::Staging::DumpAnnotations;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'dump_annotations',
    );

sub run {
    my $self    = shift;
    my $release = $self->release;
    my $acedb_path = join("/",$self->acedb_root,"wormbase_$release");

    # Get a list of dump scripts.
    # Dump scripts should abide by the following conventions.
    # 1. Be located in update/staging/annotation_dumpers
    # 2. Be named either
    #       dump_species_*   for species level data (like brief IDs)
    #       dump_resource_*  for resource level data (like laboratories)
    # 3. Follow existing examples, including available parameters.
    # 4. Dump to STDERR and STDOUT.
    # Notes:
    #
    # 1. dump_species_* will be called for each species managed by WormBase
    #    and will end up in 
    #       ${FTP_ROOT}/releases/[RELEASE]/species/[G_SPECIES]/annotation/[G_SPECIES].[RELEASE].[DESCRIPTION].txt
    #    dump_resource_* will be called once and end up in
    #       ${FTP_ROOT}/datasets-wormbase/wormbase.[RELEASE].[DESCRIPTION].txt
    # 2. The filename will be created by stripping off dump_species_ or dump_resource_.
    #     Species specific resources will be prepended with the appropriate species.
    
    my $dump_path = $self->bin_path . '/../annotation_dumpers';
    my @dump_scripts = glob("$dump_path/dump*pl");
    foreach my $script (@dump_scripts) {

	my ($description) = ($script =~ /.*\/(.*)/);
	$description    =~ s/dump_species_//;
	$description    =~ s/dump_resource_//;
	$description    =~ s/\.pl//;
	
	my $output_root = join("/",$self->ftp_releases_dir,$release); 
	
	# This is a species specific script. Try running it for each managed species.
	if ($script =~ /dump_species/) {
	    my ($species) = $self->wormbase_managed_species;  
	    foreach my $name (@$species) {
		
		my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
		# Now, for each species, iterate over the bioproject IDs.
		# These are just strings.
		my $bioprojects = $species->bioprojects;
		foreach my $bioproject (@$bioprojects) {
		    my $id = $bioproject->bioproject_id;
		    $self->log->info("   Processing bioproject: $id");
		    
		    my $output = join("/",$output_root,'species',$name,$id,'annotation');
		    $self->_make_dir($output);
		    
		    $self->log->info("dumping $script $description for $name");
		    $self->system_call("$script --path $acedb_path --species $name | gzip -c > $output/$name.$id.$release.$description.txt.gz",
				       "dumping $description script");
		}
	    }
	} elsif ($script =~ /dump_resource_/) {
	    # It's a resource. Only need to call the script once.
	    my $output = join("/",$self->ftp_root,'datasets-wormbase');
	    $self->_make_dir($output);
	    $self->_make_dir("$output/$description");
	    
	    $self->log->info("dumping $script $description");
	    $self->system_call("$script --path $acedb_path | gzip -c > $output/$description/wormbase.$release.$description.txt.gz",
			       "dumping $description script");
	}
    }
}

1;
