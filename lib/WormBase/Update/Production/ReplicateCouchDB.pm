package WormBase::Update::Production::ReplicateCouchDB;

use Moose;
use Ace;
use WWW::Mechanize;
use Config::JFDI;
use URI::Escape;
use Data::Dumper;
use HTTP::Request;
use WormBase::CouchDB;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'replicating couchdb from the master to other nodes',
);

has 'couchdb' => (
    is         => 'rw',
    lazy_build => 1);

sub _build_couchdb {
    my $self = shift;
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release });
    return $couchdb;
}


sub run {
    my $self = shift;       
    my $release = $self->release;

    my ($local_nodes)  = $self->local_couchdb_nodes;
    my ($remote_nodes) = $self->remote_couchdb_nodes;
    foreach my $node (@$local_nodes,@$remote_nodes) {
	$self->replicate($node);
    }
}



sub replicate {
    my $self        = shift;
    my $remote_node = shift;

    $self->log->info("replicating from master couchdb to $remote_node"); 
    
    my $couch  = $self->couchdb;
    my $response = $couch->replicate({ master => $self->couchdbmaster,
				       target => $remote_node . ":5984",
				       database => lc($self->release) } );
    
    if ($response->{ok}) {
	$self->log->info("successfully replicated to $remote_node");
	foreach (keys %{$response}) {
	    $self->log->info("\t","$_: " . $response->{$_});
	}			 
    } else {
	$self->log->warn("failed to replicate to $remote_node: " . $response->{error});
    }
}


1;
