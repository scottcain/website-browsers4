package WormBase::Update::Production::ReplicateCouchDB;

use local::lib '/usr/local/wormbase/website/tharris/extlib';
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
    default => 'replicate (or copy) couchdb from the staging server to production couch nodes',
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

    # Every node gets a couch, by replication
    # Reinstate if couch reads become a bottleneck.
#    my ($local_nodes)  = $self->local_couchdb_nodes;
#    my ($remote_nodes) = $self->remote_couchdb_nodes;
#    foreach my $node (@$local_nodes,@$remote_nodes) {
#	$self->replicate($node);
#    }

    # Or, we have a single couchdb host in production
    my $host = $self->couchdb_production_host;
#    $self->rsync($host);
    $self->scp($host);
}



sub rsync {
    my ($self,$node) = @_;
    $self->log->warn("rsyncing the staging couchdb to the production couchdb host $node");
    # Rsync
    my $release = lc($self->release);
    my $root    = $self->couchdb_root;
    
    $self->system_call("rsync --rsh=ssh -Cavv $root/$release.couch $node:$root",
		       'rsyncing couchdb');
    
    # Do I need to fix permissions?
#    my $ssh = $self->ssh($node);
#    $ssh->system("cd $destination_dir; tar xzf $filename.tgz") or $self->log->logdie("Couldn't unpack acedb on $node: " . $ssh->error);

}


sub scp {
    my ($self,$node) = @_;
    $self->log->warn("scping the staging couchdb to the production couchdb host $node");
    # Rsync
    my $release = lc($self->release);
    my $root    = $self->couchdb_root;

    my $ssh = $self->ssh($node);
    $ssh->system("cd $root; rm -rf $release.couch")
	or $self->log->logdie("Couldn't remove the old couhdb on $node: " . $ssh->error);
    
    $self->system_call("scp $root/$release.couch $node:$root",
		       'scping couchdb');

}



sub replicate {
    my $self        = shift;
    my $remote_node = shift;
    my $master      = $self->couchdbmaster;

    $self->log->info("replicating from master couchdb on $master to $remote_node"); 
    return if $self->couchdbmaster =~ /$remote_node/;
    
    my $couch    = $self->couchdb;

    # Get a list of available databases.
    my $databases = $couch->get_current_databases();
    foreach my $database (@$databases) {
	next unless $database =~ /^ws.*/;
	
	my $response = $couch->replicate({ master => $self->couchdbmaster,
					   target => $remote_node . ":5984",
					   database => $database } );
	
	if ($response->{ok}) {
	    $self->log->info("successfully replicated to $remote_node");
	    foreach (keys %{$response}) {
		$self->log->info("\t","$_: " . $response->{$_});
	    }			 
	} else {
	    $self->log->warn("failed to replicate to $remote_node: " . $response->{error});
	}
    }
}


1;
