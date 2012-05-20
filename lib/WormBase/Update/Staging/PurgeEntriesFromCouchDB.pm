package WormBase::Update::Staging::PurgeEntriesFromCouchDB;

use Moose;
use Ace;
use WormBase::CouchDB;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'purging specified elements from couchdb',
);

has 'class' => (
    is      => 'rw',
    );

has 'widget' => (
    is       => 'rw',
    );

has 'couchdb_host' => ( 
    is => 'rw',
    default => 'localhost:5984'
    );

has 'couchdb' => (
    is         => 'rw',
    lazy_build => 1);

sub _build_couchdb {
    my $self = shift;
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release, couchdb_host => $self->couchdb_host });
    return $couchdb;
}

has 'selective_delete' => (
    is => 'rw',
    default => 0
    );


sub run {
    my $self = shift;       
    my $release = $self->release;
    my $class   = $self->class;
    my $widget  = $self->widget;

    my $couch = $self->couchdb;
    my %objects;

    my $ace_class = ucfirst($class);
    my $db        = Ace->connect(-host=>'localhost',-port=>2005);

    $ace_class = 'CDS' if $ace_class eq 'Cds';

    my $i = $db->fetch_many($ace_class => '*');
    while (my $obj = $i->next) {
	my $uuid = join('_',lc($class),lc($widget),$obj);

	my $data;

	my $selective_delete = $self->selective_delete;
	if ($selective_delete) {
	    # Some acedb errors are cropping up and breaking widgets,
	    # but they are still being cached.  Let's selectively delete them.
	    # They have "Template::Exception" listed in content.
	    my $content = $couch->get_document($uuid);		
	    if ($content && $content->{data} && $content->{data} =~ /Template::Exception/) {
		$data  = $couch->delete_document({ uuid => $uuid, rev => $content->{_rev} });
		$objects{$obj}++;
	    }
	} else {
	    $data  = $couch->delete_document({ uuid => $uuid });	    
	    $objects{$obj}++;
        }
	
	if ($data->{reason}) {
	    print STDERR "Deleting $uuid FAILED: " . $data->{reason} . "\n";
	} else {
	    print STDERR "Deleting $uuid: success";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}	
    }

    $self->purge_entries_from_cache_log(\%objects);
}


# Selectively remove entreis from the cache log so that they can be cached again.
sub purge_entries_from_cache_log {
    my $self    = shift;
    my $objects = shift;

    my $class   = $self->class;
    my $widget  = $self->widget;
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache','logs');
    
    my $cache_log = join("/",$cache_root,"$class.txt");
    system("mv $cache_log $cache_root/$class.original.txt");
        
    open IN,"$cache_root/$class.original.txt" or die "$!";
    open OUT,">>$cache_root/$class.txt";
    
    while (<IN>) {
	chomp;
	my ($class,$obj,$name,$url,$status,$cache_stop) = split("\t");
	next if (($name eq $widget) && defined $objects->{$obj});
	print OUT join("\t",$class,$obj,$name,$url,$status,$cache_stop),"\n";
    }
    close IN;
    close OUT;
}



1;
