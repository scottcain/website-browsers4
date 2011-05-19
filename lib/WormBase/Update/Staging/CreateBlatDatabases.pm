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


has 'fatonib' => (
    is => 'ro',
    default => '/usr/local/wormbase/services/blat/bin/faToNib',
    );


sub run {
    my $self = shift;   
    my @species = $self->wormbase_managed_species;  
    
    foreach my $name (@species) {
	$self->log->info(uc($name). ': start');

	my $species = WormBase::Factory->create('Species',{ symbolic_name => $name, release => $self->release });
	$self->prepare_dna($species);
	$self->make_blatdb($species);
	$self->log->info(uc($name). ': done');
    }
}


sub prepare_dna {
    my ($self,$species) = @_;
    $self->log->debug("unpacking dna for blat databases");
    
    my $path        = $species->release_dir;      # species home
    my $fasta_file  = $species->fasta_file;       # Just the filename

    unless (-e "$path/$fasta_file") {
	$self->log->error(uc($name) . ': no fasta file found');
	return;
    }

    my $target_file = join("/",$self->blat_dir,$fasta_file);
    $target_file    =~ s/\.gz//; # Strip off the trailing .gz
 
    # Unpack mirrored fasta
    system("gunzip -c $path/fasta_file > $target_file") or $self->log->logdie("Couldn't unpack the fasta file to the blast staging directory");
    
    $self->log->debug("unpacking dna for blat databases: complete");    
    $self->log->debug("splitting $target_file into multiple fasta files");  
    
    chdir($species->blat_dir);
    
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
    my ($self,$species) = @_;
    $self->log->debug("formatting blat database for $species");
    
    my $fatonib = $self->fatonib;
        
    my $path = $species->blat_dir;
    foreach my $file (glob("$path/*dna")) {
	my ($root_dir, $nib_file_name) = $self->_parse_file_name($file) or return;
	$nib_file_name =~ s/\.dna$/\.nib/; 
	my $cmd = "$fatonib $file $path/$nib_file_name";
	$self->system_call($cmd,"running fatonib: $cmd");

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
