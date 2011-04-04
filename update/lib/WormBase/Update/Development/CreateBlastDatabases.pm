package WormBase::Update::Development::CreateBlastDatabases;

use Moose;
use local::lib '/usr/local/wormbase/website/classic/extlib';
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'creating blast databases'
    );

# Simple accessor/getter for species so I don't have to pass it around.
has 'species' => (
    is => 'rw'
    );

has 'file_template' => (
    is          => 'ro',
    isa         => 'HashRef'
    default     => sub  {
	my %types2files = (
	    nucleotide => 'genomic.fa',
	    protein    => 'peptide.fa',
	    ests       => 'ests.fa',
	    genes      => 'genes.fa',
	return \%types2files;
    },
    );

has 'blastdb_format_script' => (
    is => 'ro',
    default => '/usr/local/blast/bin/formatdb' );


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



has 'destination_path' => (
    is      => 'rw',
    lazy    => 1,
);

sub _build_destination_path { 
    my $self = shift;
    my $version = $self->version;
    my $species = $self->species;
    my $path = join('/',$self->support_databases_path,$version,'blast');
    $self->_make_dir($path);

    $self->_make_dir("$path/$species");
    return "$path/$species";
}



use File::Slurp qw(slurp);


sub run {
  my $self = shift;
  
  my $msg = 'creating blast databases for';

  my @species = $self->species_list;
  
  my $version = $self->version;
  foreach my $species (@species) {
      $self->log->info("  begin: $msg $species");

      # Set the current species so I don't have to schlep it.
      $self->species($species);    
      
      $self->create_nucleotide_dbs();
      $self->create_protein_dbs();  
      $self->create_est_db();
      $self->create_gene_db();
      $self->log->info("  end: $msg $species");
      my $master = $self->master_log;
      print $master $self->step . " $msg $species complete...\n";
  }
}


sub create_nucleotide_dbs {
    my $self = shift;
    $self->log->info("  generating $species genomic nucleotide database");

    # Copy and unpack the genomic sequence
    my $species    = $self->species;
    my $fasta      = $self->fasta_path;       # Full fasta path
    my $fasta_file = $self->fasta_file;       # Just the filename
    my $target     = join("/",$self->destination_path,$fasta_file);
    $target        =~ s/\.gz//;
 
    system("gunzip -c $fasta > $target") or die "Couldn't unpack the fasta file to the blast staging directory";
    
    $self->make_blastdb('nucleotide');
    $self->log->info("  generating $species genomic nucleotide database: complete");
}

sub create_protein_dbs {
    my $self = shift;
    my $species = $self->species;
    
    $self->log->info("  generating $species protein blast database");
    my $version = $self->version;
    
#    my $filename = $self->file_template('protein');
#    my $numeric = $self->release_id;
	
    my $blast_path = $self->destination_path

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




# Currently only for elegans
sub create_est_db {
    my $self = shift;
    my $species = shift;

    return unless $species =~ /elegans/;

    $self->log->info("  generating $species est blast database");
    $self->dump_elegans_ests;

#    my $filename = $self->file_template('protein');
#    my $numeric = $self->release_id;
	
    my $blast_path = $self->destination_path;
    my $source_file = join("/",$self->ftp_species_root_path,'c_elegans','c_elegans.' . $self->version . ".ests.fa.gz");  
    
    # Untar the output to the blast directory
    system("gunzip -c $source_file > $blast_path/$filename");
    
    $self->make_blastdb('ests');
    $self->log->info("  generating $species est blast database: complete");
}



# Create a gene database - currently only for C. elegans
sub create_gene_db {
    my $self = shift;
    return unless ($species =~ /elegans/ || $species =~ /briggsae/);
    $self->log->info("  generating $species gene blast database");
    
    my $release = $self->release;
    my $acedb = $self->acedb_path . "/wormbase_$release";

    my $filename = $self->file_template('genes');
    
    my $blast_path = $self->destination_path;

    my $bin_root = $self->bin_root;
    my $script = "$bin_root/../util/dump_nucleotide.pl";    
    system("$script $acedb $species > $blast_path/$filename");
    
    $self->make_blastdb('genes');
    $self->log->info("  generating $species gene blast database: complete");
}



sub make_blastdb {
    my ($self,$type) = @_;
    
    my $species = $self->species;
    my $version = $self->version;
    $self->log->debug("formatting $type blast database for $species");
    
    # Build the blast title
    my $title = sprintf("%s %s release [%s]",$species,$type,$version);
    
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $filename = $self->file_template($type);
    
    # Insert the title and input file
    # Not sure if this actaully gets the hash key from Moosified HashRef
    my $cmd      = sprintf($self->formatdb_strings($type),$title,$filename);
    my $formatdb = $self->blastdb_format_script;
    my $full_cmd = "$formatdb $cmd";
    
    
    my $blastdb_dir = $self->destination_path;
    chdir($blastdb_dir); 

    
    $self->check_input_file($filename);

    system("$full_cmd") && $self->log->logdie("something went wrong formatting the $type database for $species: $!");
    $self->log->debug("formatting $type blast database for $species: complete");
}

1;
