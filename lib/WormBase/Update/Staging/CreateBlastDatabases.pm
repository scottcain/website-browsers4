package WormBase::Update::Staging::CreateBlastDatabases;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'build BLAST databases',
    );

has 'formatdb_strings' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
	my %commands = (
	    genomic    => qq{-p F -t '%s' -i %s},
	    ests       => qq{-p F -t '%s' -i %s},
	    peptide    => qq{-p T -t '%s' -i %s},
	    genes      => qq{-p F -t '%s' -i %s},
	    );
	return \%commands;
    },
    );


sub run {
    my $self = shift;
 
    $self->support_databases_dir;
   
    # get a list of (symbolic g_species) names
    my ($species) = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	$self->log->info("Processing species $name: start");

	# Creating blast databases by system calls to shell scripts.
	# Nucleotide BLAST DBs
#	$self->system_call( $self->create_blastdb_script . " $release nucleotide $name",
#			    "creating nucleotide blastdb for $name");
#
#	# Protein BLAST DBs
#	$self->system_call( $self->create_blastdb_script . " $release protein $name",
#			    "creating protein blastdb for $name");

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {
	    my $id = $bioproject->bioproject_id;
	    $self->log->info("   Processing bioproject: $id");
	    $self->create_genomic_blast_db($bioproject);
	    $self->create_protein_db($bioproject);
	    $self->create_est_db($bioproject);   # elegans only
            # No longer in use as of WS230
            #	$self->create_gene_db($species);  # elegans only
	    $self->log->info("   $name ($id): done");
	}
    }
}



sub create_genomic_blast_db {
    my ($self,$bioproject) = @_;

    my $name = $bioproject->symbolic_name;

    # Copy and unpack the genomic sequence, if it exists.
    my $fasta_file = join("/",$bioproject->release_dir,$bioproject->genomic_fasta);

    unless (-e $fasta_file && -s $fasta_file) {
	$self->log->error(uc($name) . ": has no fasta sequence; not building genomic blast");
	return;
    }

    my $target     = join("/",$bioproject->blast_dir, "genomic.fa");
    $target        =~ s/\.gz//;

    # Don't unpack if file already exists.
    unless ($self->check_output_file($target)) {
	system("gunzip -c $fasta_file > $target") && $self->log->logdie(uc($name) . ": couldn't unpack fasta file to $target");
    }

    $self->make_blastdb('genomic',$bioproject);
    $self->log->info("$name: successfully built nucleotide blast db");
}


sub create_protein_db {
    my ($self,$bioproject) = @_;

    my $name = $bioproject->symbolic_name;
    	
    # Copy and unpack the genomic sequence, if it exists.
    my $fasta_file = join("/",$bioproject->release_dir,$bioproject->protein_fasta);

    unless (-e $fasta_file && -s $fasta_file) {
	$self->log->error(uc($name) . ": has no fasta sequence; not building protein blast");
	return;
    }

    my $target     = join("/",$bioproject->blast_dir, "peptide.fa");
    $target        =~ s/\.gz//;

    # Don't unpack if we're already there.
    unless ($self->check_output_file($target)) {
	system("gunzip -c $fasta_file > $target") && $self->log->logdie(uc($name) . ": couldn't unpack fasta file to $target");
    }

    $self->make_blastdb('peptide',$bioproject);
    $self->log->info("$name: successfully built protein blast db");
}




sub create_est_db {
    my ($self,$bioproject) = @_;
    my $name = $bioproject->symbolic_name;
    return unless $name =~ /elegans/;

    # The ESTs file is created by Hinxton
    # $self->dump_elegans_ests;
    
    my $blast_path = $bioproject->blast_dir;
    my $source_file = join("/",$bioproject->release_dir,$bioproject->ests_file);
    
    # Untar the output to the blast directory unless the file already exists.
    unless ($self->check_output_file("$blast_path/ests.fa")) {
	$self->system_call("gunzip -c $source_file > $blast_path/ests.fa",
			   'checking blast output file');
    }
    $self->make_blastdb('ests',$bioproject);
    $self->log->info("$name: successfully built est blast db");
}

# 2012.02.07: Retired by TH. This is absurd.

# The "Genes" blast database.
# Currently.
# TODO: We will drop creation of this (retire dump_nucleotide.pl)
# REPLACE with concatenation of cds_transcript and ncrna_transcripts.
# Create a gene database. This isn't really "genes" but genomic clones.
sub create_gene_db {
    my ($self,$bioproject) = @_;
    my $name = $bioproject->symbolic_name;
    return unless ($name =~ /elegans/ || $name =~ /briggsae/);
    
    my $release = $self->release;

    my $filename = 'genes.fa';
    
    my $blast_path = $bioproject->blast_dir;

    my $bin_path = $self->bin_path;
    my $script = "$bin_path/../helpers/dump_nucleotide.pl";    
    $self->log->info("running dump_nucleotide.pl");
    # This doesn't return 0 and in turn fails.
#    $self->system_call("$script $release $name > $blast_path/$filename",
#		       "cmd: $script $release $name > $blast_path/$filename");
    unless ($self->check_output_file("$blast_path/$filename")) {
	system("$script $release $name > $blast_path/$filename");
    }
    
    $self->make_blastdb('genes',$bioproject);
    $self->log->info("$name: successfully built gene blast db");
}


sub make_blastdb {
    my ($self,$type,$bioproject) = @_;
    
    # Pre-emtpively check and see if the blast databases already exist
    # to avoid recomputation.
    # This FAILS in cases where we haven't yet even tried to create BLAST databases...
    # return if $self->check_blast_output($type,$species);

    my $name    = $bioproject->symbolic_name;
    my $release = $self->release;
    
    # Build the blast title
    my $title = sprintf("%s %s release [%s]",$name,$type,$release);
    my $filename = "$type.fa";
    
    # Insert the title and input file
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $cmd      = sprintf($self->formatdb_strings->{$type},$title,$filename);
    my $formatdb = $self->blastdb_format_script;
    my $full_cmd = "$formatdb $cmd";

    my $blastdb_dir = $bioproject->blast_dir;
    chdir($blastdb_dir); 
    
    $self->system_call($full_cmd,"making blast database via command $full_cmd");
    
    # Check the blast outputs.
    $self->check_blast_output($type,$bioproject);
    $self->log->debug("formatting $type blast database for $name: complete");
}


sub check_blast_output {
    my ($self,$type,$bioproject) = @_;
    
    my $name = $bioproject->symbolic_name;
    
    my $blast_dir = $bioproject->blast_dir;
    my @suffixes;
    if ($type eq 'genomic' || $type eq 'genes' || $type eq 'ests') {
	@suffixes = (qw/nhr nin nsq/);
    } else {
	@suffixes = (qw/phr pin psq/);
    }

    foreach my $suffix (@suffixes) {
	$self->log->error("Building the $type BLAST database for $name FAILED")
	    unless (-e "$blast_dir/$type.fa.$suffix" && -s "$blast_dir/$type.fa.$suffix");
    }
    return 1;
}



1;
