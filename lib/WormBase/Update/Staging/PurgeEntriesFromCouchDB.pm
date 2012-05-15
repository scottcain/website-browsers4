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


sub run {
    my $self = shift;       
    my $release = $self->release;
    my $class   = $self->class;
    my $widget  = $self->widget;

    my $couch = $self->couchdb;

    my $ace_class = ucfirst($class);
    my $db        = Ace->connect(-host=>'localhost',-port=>2005);

    $ace_class = 'CDS' if $ace_class eq 'Cds';

    my $i = $db->fetch_many($ace_class => '*');
    while (my $obj = $i->next) {
	my $uuid = join('_',lc($class),lc($widget),$obj);

	# Some acedb errors are cropping up and breaking widgets,
	# but they are still being cached.  Let's selectively delete them.
	# The have "Template::Exception" listed in content.
	my $content = $couch->get_document($uuid);
	if ($content->{data} && $content->{data} =~ /Template::Exception/) {
	    
	    my $data  = $couch->delete_document({ uuid => $uuid, rev = $content->{_rev} });
	    if ($data->{reason}) {
		print STDERR "Deleting $uuid FAILED: " . $data->{reason} . "\n";
	    } else {
		print STDERR "Deleting $uuid: success";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	    }
	}
    }
}


1;
