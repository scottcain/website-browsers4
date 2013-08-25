package WormBase::Update::Staging::CheckCachedContent;

use Moose;
use Ace;
use WWW::Mechanize;
use URI::Escape;
use Data::Dumper;
use HTTP::Request;
use WormBase::CouchDB;
#use LWP::Simple;
use LWP::UserAgent;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'do some simple error checking on cached content',
);

has 'couchdb' => (
    is         => 'rw',
    lazy_build => 1);

sub _build_couchdb {
    my $self = shift;

    # Discover where our target couchdb is. This is used for 
    #     1. creating a new couchdb
    #     2. bulk operations against the couchdb
    #     3. checking if a URL has already been cached.    
    my $method     = 'couchdb_host_' . $self->couchdb_host;
    my $couch_host = $method =~ 'localhost' ? $method : $self->$method;
    
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release, couchdb_host => $couch_host });
    return $couchdb;
}


has 'couchdb_host' => (
    is      => 'rw',
    default => 'localhost',
    );


sub run {
    my $self = shift;       
    my $release = $self->release;
#    $self->dump_object_lists();   # Created by PrecacheContent.pm

    $self->check_for_broken_widgets();
}


sub check_for_broken_widgets {
    my $self = shift;
    
    $|++;    
    my $couch = $self->couchdb;

    my $db      = Ace->connect(-host=>'localhost',-port=>2005) or warn;
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");

    my $master_log_file = join("/",$cache_root,'logs',"gene.test.log");
    open MASTER,">>$master_log_file";

    print MASTER join("\t",'GENE','HAS_SEQUENCES?','SEQUENCES_STATUS','LOCATION_STATUS'),"\n";

    my $master_error_file= join("/",$cache_root,'logs',"gene.test.err");
    open ERROR,">>$master_error_file";
    print ERROR join("\t",'GENE','HAS_SEQUENCES?','SEQUENCES_STATUS','LOCATION_STATUS'),"\n";

    my %total;
    
    my @objects = $db->fetch('Gene' => '*');
    my $count;
    foreach my $gene (@objects) {
	$count++;
	next unless $count  >= 199990;
#	die if $count == 200000;
	$total{genes_tested}++;
	
    
	# Should this gene have a location and sequence set?
	# If the gene has associated sequences, it SHOULD
	# have both a location and sequences widget
	# What parameters?
	# Gene type?
	# Chromosome
	my $has_sequences;
	my %seen;
	my @seqs = grep { !$seen{$_}++} $gene->Corresponding_transcript;
	
	for my $cds ($gene->Corresponding_CDS) {
	    next if defined $seen{$cds};
	    my @transcripts = grep {!$seen{$cds}++} $cds->Corresponding_transcript;	    
	    push (@seqs, @transcripts ? @transcripts : $cds);
	}

	if (@seqs > 0) {
	    $has_sequences = 1;
	} elsif ($gene->Corresponding_Pseudogene) {
	    $has_sequences = 1;
	} else {
	    $has_sequences = 0;
	}
	
	$self->log->info("$gene expect sequences: $has_sequences");
	my %status;

	# Via couchdb directly
	my $content = $self->get_document_from_couchdb('gene','location',$gene);
	if ($content) {
	    if ($content->{data} =~ /pos_string/i) {
		# pos_string shouldn't be present without sequences
		$status{location} = $has_sequences ? 'correct: pos_string found' : 'broken';
	    } else {
		$status{location} = $has_sequences ? 'broken' : 'correct: NO pos_string found';
#		    push @{$total{location_failed}},$gene;
	    }
	} else {
	    $status{location} = 'GET failed';
	}
	
	my $seq_content = $self->get_document_from_couchdb('gene','sequences',$gene);
	if ($seq_content) {
	    if ($seq_content->{data} =~ /cds/i) {
		# cds shoulnd't be present if we don't have sequences
		$status{sequences} = $has_sequences ? 'correct: cds string found' : 'broken';
	    } else {
		$status{sequences} = $has_sequences ? 'broken' : 'correct: NO cds string found';
#		    push @{$total{sequences_failed}},$gene;
	    }
	} else {
	    $status{sequences} = 'GET failed';
	} 	    
	
	if ($status{location} eq 'broken' || $status{sequences} eq 'broken') {
	    print ERROR join("\t",$gene,$has_sequences,$status{sequences},$status{location}),"\n";
	}
	
	
	print MASTER join("\t",$gene,$has_sequences,$status{sequences},$status{location}),"\n";
    }
}	


sub get_document_from_couchdb {
    my ($self,$class,$widget,$name) = @_;
    
    # URL-ify (specific escaping for couch lookups)
    $name =~ s/\#/\%2523/g;
    $name =~ s/\:/\%253A/g;
    $name =~ s/\s/\%2520/g;
    $name =~ s/\[/\%255B/g;
    $name =~ s/\]/\%255D/g;

    my $couch = $self->couchdb;
    my $uuid  = join("_",$class,$widget,$name);
    my $data  = $couch->get_document($uuid);
    return $data ? $data : 0;
}

1;
