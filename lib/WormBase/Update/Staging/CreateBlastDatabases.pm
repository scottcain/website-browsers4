package WormBase::Update::Staging::CreateBlastDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
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
    
    # get a list of (symbolic g_species) names
    my ($species) = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
#	next unless $name =~ /elegans/;
	$self->log->info("$name: start");

	# Creating blast databases by system calls to shell scripts.
	# Nucleotide BLAST DBs
#	$self->system_call( $self->create_blastdb_script . " $release nucleotide $name",
#			    "creating nucleotide blastdb for $name");
#
#	# Protein BLAST DBs
#	$self->system_call( $self->create_blastdb_script . " $release protein $name",
#			    "creating protein blastdb for $name");
		
	$self->create_genomic_blast_db($species);
	$self->create_protein_db($species);
	$self->create_est_db($species);   # elegans only
	$self->create_gene_db($species);  # elegans only
	$self->log->info("$name: done");
    }
}



sub create_genomic_blast_db {
    my ($self,$species) = @_;

    my $name = $species->symbolic_name;

    # Copy and unpack the genomic sequence, if it exists.
    my $fasta_file = join("/",$species->release_dir,$species->genomic_fasta);

    unless (-e $fasta_file && -s $fasta_file) {
	$self->log->error(uc($name) . ": has no fasta sequence; not building genomic blast");
	return;
    }

    my $target     = join("/",$species->blast_dir, "genomic.fa");
    $target        =~ s/\.gz//;

    # Don't unpack if file already exists.
    unless ($self->check_output_file($target)) {
	system("gunzip -c $fasta_file > $target") && $self->log->logdie(uc($name) . ": couldn't unpack fasta file to $target");
    }

    $self->make_blastdb('genomic',$species);
    $self->log->info("$name: successfully built nucleotide blast db");
}


sub create_protein_db {
    my ($self,$species) = @_;

    my $name = $species->symbolic_name;
    	
    # Copy and unpack the genomic sequence, if it exists.
    my $fasta_file = join("/",$species->release_dir,$species->protein_fasta);

    unless (-e $fasta_file && -s $fasta_file) {
	$self->log->error(uc($name) . ": has no fasta sequence; not building protein blast");
	return;
    }

    my $target     = join("/",$species->blast_dir, "peptide.fa");
    $target        =~ s/\.gz//;

    # Don't unpack if we're already there.
    unless ($self->check_output_file($target)) {
	system("gunzip -c $fasta_file > $target") && $self->log->logdie(uc($name) . ": couldn't unpack fasta file to $target");
    }

    $self->make_blastdb('peptide',$species);
    $self->log->info("$name: successfully built protein blast db");
}




sub create_est_db {
    my ($self,$species) = @_;
    my $name = $species->symbolic_name;
    return unless $name =~ /elegans/;

    # The ESTs file is created by Hinxton
    # $self->dump_elegans_ests;
    
    my $blast_path = $species->blast_dir;
    my $source_file = join("/",$species->release_dir,$species->ests_file);
    
    # Untar the output to the blast directory unless the file already exists.
    unless ($self->check_output_file("$blast_path/ests.fa")) {
	$self->system_call("gunzip -c $source_file > $blast_path/ests.fa",
			   'checking blast output file');
    }
    $self->make_blastdb('ests',$species);
    $self->log->info("$name: successfully built est blast db");
}

# The "Genes" blast database.
# Currently.
# TODO: We will drop creation of this (retire dump_nucleotide.pl)
# REPLACE with concatenation of cds_transcript and ncrna_transcripts.
# Create a gene database. This isn't really "genes" but genomic clones.
sub create_gene_db {
    my ($self,$species) = @_;
    my $name = $species->symbolic_name;
    return unless ($name =~ /elegans/ || $name =~ /briggsae/);
    
    my $release = $self->release;

    my $filename = 'genes.fa';
    
    my $blast_path = $species->blast_dir;

    my $bin_path = $self->bin_path;
    my $script = "$bin_path/../helpers/dump_nucleotide.pl";    
    $self->log->info("running dump_nucleotide.pl");
    # This doesn't return 0 and in turn fails.
#    $self->system_call("$script $release $name > $blast_path/$filename",
#		       "cmd: $script $release $name > $blast_path/$filename");
    unless ($self->check_output_file("$blast_path/$filename")) {
	system("$script $release $name > $blast_path/$filename");
    }
    
    $self->make_blastdb('genes',$species);
    $self->log->info("$name: successfully built gene blast db");
}


sub make_blastdb {
    my ($self,$type,$species) = @_;
    
    # Pre-emtpively check and see if the blast databases already exist
    # to avoid recomputation.
    # This FAILS in cases where we haven't yet even tried to create BLAST databases...
    # return if $self->check_blast_output($type,$species);

    my $name    = $species->symbolic_name;
    my $release = $self->release;
    
    # Build the blast title
    my $title = sprintf("%s %s release [%s]",$name,$type,$release);
    my $filename = "$type.fa";
    
    # Insert the title and input file
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $cmd      = sprintf($self->formatdb_strings->{$type},$title,$filename);
    my $formatdb = $self->blastdb_format_script;
    my $full_cmd = "$formatdb $cmd";

    my $blastdb_dir = $species->blast_dir;
    chdir($blastdb_dir); 
    
    $self->system_call($full_cmd,'making blast database');
    
    # Check the blast outputs.
    $self->check_blast_output($type,$species);
    $self->log->debug("formatting $type blast database for $name: complete");
}


sub check_blast_output {
    my ($self,$type,$species) = @_;
    
    my $name = $species->symbolic_name;
    
    my $blast_dir = $species->blast_dir;
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
