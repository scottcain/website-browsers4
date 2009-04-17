package Update::CreateEPCRDatabases;

use strict;
use base 'Update';
use IO::File;

# The symbolic name of this step
sub step { return 'create epcr databases'; }

# Create a single file for driving e-pcr
use constant CHUNKSIZE  => 1_000; # size of each line
use constant OVERLAP    => 50;     # oligos can't be larger than this

sub run {
    my $self = shift;
    
    my $species = $self->species;
    
    my $msg = 'creating epcr and oligo databases for';
    # Stash some variables so I don't have to keep regenerating them over and over.  
    $self->target_root($self->get_epcr_dir);
    
    foreach my $species (@$species) {
	$self->logit->info("  begin: creating $msg $species");    
	$self->_make_dir($self->mirror_dir);    
	$self->species_root($self->target_root . "/$species");
	$self->_make_dir($self->species_root);
	$self->create_epcr_database($species);
	$self->logit->info("  end: $msg $species");    
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}

sub create_epcr_database {
    my ($self,$species) = @_;
    $self->logit->debug("generating epcr database");
    
    my $release = $self->release;  
    
    # mirror if necessary
    $self->mirror_genomic_sequence($species);     
    $self->_remove_dir($self->mirror_dir);
    
    my $custom_filename = $self->get_filename('genomic_fasta_archive',$species); # Genomic fasta filename
    my $generic_filename = $self->get_filename('epcr');  # Filename for the epcr target
    
    my $target_file = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna/$custom_filename.gz");
    chdir($self->species_root) or $self->logit->warn("couldnt chdir $self->species_root");

    # Gunzip the fasta file, copying it to the name of our epcr file
    #system("gunzip -c $target_file > $generic_filename");
    # Or just copy it
    system("cp $target_file $generic_filename");
    
    $self->create_oligo_db($species); 
    $self->logit->debug("generating epcr database: complete");
}


sub create_oligo_db {
    my ($self,$species) = @_;
    $self->logit->debug("creating oligo db for $species");
    
    my $generic_filename = $self->get_filename('oligos');
    my $epcr_filename    = $self->get_filename('epcr');
    chdir($self->species_root);
    my $fh = IO::File->new(">$generic_filename") or $self->logit->logdie("couldn't create the oligo db file at $generic_filename");
    
    my ($sequence,$offset,$id);
    
    @ARGV = glob($self->species_root . "/$epcr_filename*");
    
    # We should already be unzipped.
    foreach (@ARGV) {
	$_ = "gunzip -c $_ |" if /\.gz$/;
    }
    
    while (<>) {
	chomp;
	if (/>(\S+)/) {
	    $self->_do_dump($id,\$offset,$fh,\$sequence) if $id;
	    $id = $1;
	    $id =~ s/^CHROMOSOME_//;
	    $sequence = '';
	    $offset   = 0;
	    next;
	}
	$sequence .= $_;
	$self->_do_dump($id,\$offset,$fh,\$sequence) if $id;
    }
    $self->_do_dump($id,\$offset,$fh,\$sequence,1) if $id;
    $self->logit->debug("creating oligo db for $species: complete");
}

sub _do_dump {
    my ($self,$id,$offset,$fh,$seqref,$finish) = @_;
    my $limit  = $finish ? 0 : CHUNKSIZE;
    while (length $$seqref > $limit ) {
	my $seg = substr($$seqref,0,CHUNKSIZE);
	print $fh "$id:$$offset:$seg\n";
	substr($$seqref,0,CHUNKSIZE - OVERLAP) = '';
	$$offset += CHUNKSIZE - OVERLAP;
    }
}


1;
