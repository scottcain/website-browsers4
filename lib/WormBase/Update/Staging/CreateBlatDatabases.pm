package WormBase::Update::Staging::CreateBlatDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use Bio::SeqIO;
extends qw/WormBase::Update/;


# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'building BLAT databases',
    );





# Will these (and similar methods) be updated everytime I reset species?
# Do I need to trigger them to be built anew?
has 'destination_dir' => (
    is      => 'ro',
    lazy    => 1,
);

sub _build_destination_dir { 
    my $self = shift;
    my $version = $self->version;
    my $species = $self->species;
    my $path = join('/',$self->support_databases_path,$version,'blat');
    $self->_make_dir($path);

    $self->_make_dir("$path/$species");
    return "$path/$species";
}

has 'fatonib' => (
    is => 'ro',
    default => '/usr/local/wormbase/services/blat/bin/faToNib',
    );


sub run {
    my $self = shift;
    
    my $msg = 'creating blat databases for';
    my @species = $self->ws_release_species_list;  
    
    my $version = $self->version;
    foreach my $species (@species) {
	$self->log->debug("begin: $msg $species");
	
	# Set the current species so I don't have to schlep it.
	$self->species($species);	
	$self->prepare_dna();
	$self->make_blatdb();
	$self->log->debug("end: $msg $species");    
    }
}


sub prepare_dna {
    my $self = shift;
    $self->log->debug("unpacking dna for blat databases");
    
    my $release     = $self->release;
    my $path        = $self->ftp_single_species_dir;
    my $fasta_file  = $self->fasta_file;       # Just the filename

    unless (-e "$path/$fasta_file") {
	$self->log->logdie("We couldn't find a fasta file for $species");
    }

    my $target_file = join("/",$self->destination_dir,$fasta_file);
    $target_file    =~ s/\.gz//; # Strip off the trailing .gz
 
    # Unpack mirrored fasta
    system("gunzip -c $path/fasta_file > $target_file") or $self->log->logdie("Couldn't unpack the fasta file to the blast staging directory");
    
    $self->log->debug("unpacking dna for blat databases: complete");    

    # Split the fasta
    my ($self,$path,$file) = @_;
    
    $self->log->debug("splitting $target_file into multiple fasta files");  
    
    chdir($self->destination_dir);
    
    my $seqIO = Bio::SeqIO->new(-file => $target_file, -format => 'fasta');
    my $counter;
    while (my $seq = $seqIO->next_seq()) {
	$counter++;    
	my $id = $seq->display_id;
	my $seqout = Bio::SeqIO->new(-format => 'Fasta', -file => ">$id.dna");
	$seqout->write_seq($seq);
    }
    $self->log->debug("splitting $target_file in multiple fasta files: complete");
}


sub make_blatdb {
    my $self = shift;
    my $species = $self->species;
    $self->log->debug("formatting blat database for $species");
    
    my $fatonib = $self->fatonib;
        
    my $path = $self->destination_dir;
    foreach my $file (glob("$path/*dna")) {
	my ($root_dir, $nib_file_name) = $self->_parse_file_name($file) or return;
	$nib_file_name =~ s/\.dna$/\.nib/; 
	my $cmd = "$fatonib $file $path/$nib_file_name";
	system($cmd) && $self->log->logdie("Something went wrong formatting the $species blat database: $!");
    }
    $self->log->debug("formatting blat database for $species: complete");
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
