package WormBase::Update::Staging::CreateBlastDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use File::Slurp qw(slurp);
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
	    nucleotide => qq{-p F -t '%s' -i %s},
	    ests       => qq{-p F -t '%s' -i %s},
	    protein    => qq{-p T -t '%s' -i %s},
	    genes      => qq{-p F -t '%s' -i %s},
	    );
	return \%commands;
    },
    );



# Rebuilt with each new species?
has 'destination_dir' => (
    is      => 'rw',
    lazy    => 1,
);

sub _build_destination_dir { 
    my $self = shift;
    my $release = $self->release;
    my $species = $self->species;
    my $path = join('/',$self->support_databases_dir,$release,'blast');
    $self->_make_dir($path);

    $self->_make_dir("$path/$species");
    return "$path/$species";
}



sub run {
    my $self = shift;
    
    my $msg = 'creating blast databases for';
    
    # get a list of (symbolic g_species) names
    my @species = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@species) {
	my $species = WormBase::Species->new(-name => $name);

	# Set the current species so I don't have to schlep it.
	$self->species($species);    
	

	# Creating blast databases by system calls to shell scripts.
	$self->log->debug("  begin: creating nucleotide blastdb for $species");
	my $result = system($self->create_blastdb_script . " $release nucleotide $species");
	$result == 0
	    ? $self->log->debug("  end: successfully created nucleotide blastdb for $species")
	    : $self->log->warn("  end: failed to create nucleotide blastdb for $species");
	
	$self->log->debug("  begin: creating protein blastdb for $species");
	my $result = system($self->create_blastdb_script . " $release protein $species");
	$result == 0
	    ? $self->log->debug("  end: successfully created protein blastdb for $species")
	    : $self->log->warn("  end: failed to create protein blastdb for $species");
	
	
#	$self->create_genomic_blast_db();
#	$self->create_protein_db();
	$self->create_est_db();   # elegans only
	$self->create_gene_db();  # elegans only
	$self->log->debug("end: $msg $species");
    }
}

=head1

# DEPRECATED. Now farming this out to a shell script.
sub create_genomic_blastdb {
    my $self = shift;
    $self->log->debug("  generating $species genomic nucleotide database");

    # Copy and unpack the genomic sequence, if it exists.
    my $species    = $self->species;
    my $fasta_file = $self->fasta_file;       # Just the filename
    my $target     = join("/",$self->destination_dir,$fasta_file);
    $target        =~ s/\.gz//;
 
    system("gunzip -c $fasta > $target") or die "Couldn't unpack the fasta file to the blast staging directory";
    
    $self->make_blastdb('nucleotide');
    $self->log->debug("  generating $species genomic nucleotide database: complete");
}

# DEPRECATED. Now farming this out to a shell script.
sub create_protein_dbs {
    my $self = shift;
    my $species = $self->species;
    
    $self->log->info("  generating $species protein blast database");
    my $version = $self->version;
    	
    my $blast_path = $self->destination_dir;

    # "Discover" the *pep tarball.
    my $path = $self->ftp_species_path;
    my $wormpep = glob("$path/*pep.fa.gz");
    if ($wormpep) {
       
	my $unpack = "gunzip";

	# Unpack the tarball package
	chdir($blast_path);
	my $cmd = <<END;
gunzip -c $path/$wormpep > $filename
END
;
	
	system($cmd);	
	$self->make_blastdb('protein');
    } else {
	$self->log->logdie("No peptide file for " . $self->species);
    }
    $self->log->info("generating $species protein blast database: complete");
}

=cut



# Currently only for elegans
sub create_est_db {
    my $self = shift;
    my $species = shift;

    return unless $species =~ /elegans/;

    $self->log->debug("  generating $species est blast database");
    $self->dump_elegans_ests;
	
    my $blast_path = $self->destination_dir;
    my $source_file = join("/",$self->ftp_releases_dir,'species',$species,'c_elegans.' . $self->release . ".ests.fa.gz");  
    
    # Untar the output to the blast directory
    system("gunzip -c $source_file > $blast_path/ests.fa");
    
    $self->make_blastdb('ests');
    $self->log->info("generating $species est blast database: complete");
}



# Create a gene database
sub create_gene_db {
    my $self = shift;
    return unless ($species =~ /elegans/ || $species =~ /briggsae/);
    $self->log->debug("generating $species gene blast database");
    
    my $release = $self->release;
    my $acedb = $self->acedb_root . "/wormbase_$release";

    my $filename = 'genes.fa';
    
    my $blast_path = $self->destination_dir;

    my $bin_root = $self->bin_root;
    my $script = "$bin_root/../helpers/dump_nucleotide.pl";    
    system("$script $acedb $species > $blast_path/$filename");
    
    $self->make_blastdb('genes');
    $self->log->info("  generating $species gene blast database: complete");
}



sub make_blastdb {
    my ($self,$type) = @_;
    
    my $species = $self->species;
    my $release = $self->release;
    $self->log->debug("formatting $type blast database for $species");
    
    # Build the blast title
    my $title = sprintf("%s %s release [%s]",$species,$type,$release);
    
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $filename = "$type.fa";
    
    # Insert the title and input file
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $cmd      = sprintf($self->formatdb_strings($type),$title,$filename);
    my $formatdb = $self->blastdb_format_script;
    my $full_cmd = "$formatdb $cmd";
       
    my $blastdb_dir = $self->destination_dir;
    chdir($blastdb_dir); 
    
#    $self->check_input_file($filename);

    system("$full_cmd") && $self->log->logdie("something went wrong formatting the $type database for $species: $!");
    $self->log->debug("formatting $type blast database for $species: complete");
}

1;
