package Update::CreateBlatDatabases;

use strict;
use Ace;
use base 'Update';
use File::Slurp qw(slurp);
use Bio::SeqIO;

# The symbolic name of this step
sub step { return 'create blat databases'; }

sub run {
    my $self = shift;
    
    my $msg = 'creating blat databases for';
    my $species = $self->species;
    # Stash some variables so I don't have to keep regenerating them over and over.  
    $self->target_root($self->get_blatdb_dir);
    
    foreach my $species (@$species) {
#      next unless $species =~ /elegans/;
	$self->logit->info("  begin: $msg $species");
	$self->_make_dir($self->mirror_dir);
	$self->species_root($self->target_root . "/$species");
	$self->_make_dir($self->species_root);
	$self->create_blat_dbs($species);
	$self->logit->info("  end: $msg $species");    
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}


sub create_blat_dbs {
    my ($self,$species) = @_;
    $self->logit->debug("fetching dna for blat databases");
    
    my $target_path      = $self->species_root;
    
    # mirror if necessary
    $self->mirror_genomic_sequence($species);           
    $self->_remove_dir($self->mirror_dir);
    
    # Unpack
    my $custom_filename = $self->get_filename('genomic_fasta_archive',$species);   # Genomic fasta filename on the FTP site
    my $generic_filename = $self->get_filename('nucleotide_blast');                # Name of genomic file for blat
    
    my $target_file = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna/$custom_filename.gz");      
    system("gunzip -c $target_file > $target_path/$generic_filename");
    
    $self->logit->debug("fetching dna for blat databases: complete");
    
    $self->split_fasta($self->species_root,$generic_filename);
    $self->make_blatdb($species);   
}

sub make_blatdb {
    my ($self,$species) = @_;
    $self->logit->debug("formatting blat database for $species");
    
    my $fatonib = $self->fatonib;
    
    # Fatonib
    foreach my $file (glob($self->species_root . "/*dna")) {
	my ($root_dir, $nib_file_name) = $self->_parse_file_name($file) or return;
	$nib_file_name =~ s/\.dna$/\.nib/; 
	my $species_root = $self->species_root;
	my $cmd = "$fatonib $file $species_root/$nib_file_name";
	system($cmd) && $self->logit->logdie("Something went wrong formatting the $species blat database: $!");
    }
    $self->logit->debug("formatting blat database for $species: complete");
}


sub split_fasta {
    my ($self,$path,$file) = @_;
    
    $self->logit->debug("splitting $path/$file into multiple fasta files");  
    
    chdir($path);
    
    my $seqIO = Bio::SeqIO->new(-file => "$path/$file", -format => 'fasta');
    my $counter;
    while (my $seq = $seqIO->next_seq()) {
	$counter++;    
	my $id = $seq->display_id;
	my $seqout = Bio::SeqIO->new(-format => 'Fasta', -file => ">$id.dna");
	$seqout->write_seq($seq);
    }
    $self->logit->debug("splitting $path/$file in multiple fasta files: complete");
}

sub _parse_file_name {
    my ($self,$file_name) = @_;
    
    my $i = $file_name;
    $i =~ s/\/+/\//g;
    
    if ($i eq '/') {
	return ('/', '');
    }
    
    $i =~ s/\/$//;
    if ($i =~ s/\/([^\/]+)$//) {
	return ($i, $1);
    }
    
    return;
}


1;
