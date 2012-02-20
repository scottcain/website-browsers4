package WormBase::CouchDB;

# Simple class for interacting with our CouchDB.
# Currently only supports creating databases,
# adding and fetching documents.  Document deletes
# and updates not yet supported.
use lib '/usr/local/wormbase/website/tharris/extlib';
use Moose;
use URI::Escape;
use JSON::Any qw/XS JSON/;
use HTTP::Request::Common;

with 'WormBase::Roles::Config';

has ua              => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_ua' );
has useragent_class => ( isa => 'Str', is => 'ro', default => 'LWP::UserAgent' );
has useragent       => ( isa => 'Str', is => 'ro', default => "WormBase::Update/0.01" );
#has useragent_args  => ( isa => 'HashRef', is => 'ro', default => sub { {} } );
has _json_handler   => (
    is      => 'rw',
    default => sub { JSON::Any->new(utf8 => 1) },
    handles => { _from_json => 'from_json' },
    );
#has 'release'       => ( is => 'rw' );

sub _build_ua {
    my $self = shift;
    
    eval "use " . $self->useragent_class;

    croak $@ if $@;
    
#    my $ua = $self->useragent_class->new(%{$self->useragent_args});
    my $ua = $self->useragent_class->new();
    $ua->agent($self->useragent);
    $ua->env_proxy;
    $ua->timeout(6000);  # Arbitrarily large timeout; initial replication is expensive.
    return $ua;
}

# Symbolic name is simply the supplied releases
has 'db_symbolic_name' => (
    is => 'rw',
    lazy_build => 1 );

sub _build_db_symbolic_name {
    my $self    = shift;
    return $self->release;
}    

# After object construction, make sure that the database exists.
#sub BUILD {
#    my $self = shift;
#    $self->create_database();
#}

sub test_connection {
    my $self = shift;

}


# curl -X PUT $couchdb/$release"
sub create_database {
    my $self     = shift;
    my $host     = shift;
    my $database = shift;

    my $msg;

    # trying to create a database on a different target
    if ($host && $database) {	
	$msg  = $self->_prepare_request({method   => 'PUT',
					 database => "$database",
					 host     => $host,
					});
    } else {
	$msg  = $self->_prepare_request({method   => 'PUT',
					 database => lc($self->release),
					});
    }
    
    my $res = $self->_send_request($msg);    
    my $data =  $self->_parse_result($res);
    return $data;
}

sub get_current_databases {
    my $self = shift;
    my $master = $self->couchdbmaster;
    my $msg    = $self->_prepare_admin_request({master   => $master,
						method   => 'GET',						
						path     => '_all_dbs',
					       });
    my $res = $self->_send_request($msg); 
    my $data =  $self->_parse_result($res);
    return $data;
}


# curl -X POST http://127.0.0.1:5984/_replicate  \
#   -d '{"source":"database", "target":"http://admin:password@127.0.0.1:5984/database"}' -H "Content-Type: application/json"

# curl -X POST http://127.0.0.1:5984/_replicate  \
#   -d '{"source":"ws226", "target":"http://206.108.125.165:5984/ws226"}' -H "Content-Type: application/json"


sub replicate {
    my ($self,$params) = @_;
    my $master   = $params->{master};
    my $target   = $params->{target};
    my $database = $params->{database};

    # Create the database on the target host.
    $self->create_database($target,$database);
    
    # Manually costructing JSON. How stupid.
    my $content = '{"source":"' . $database . '","target":"' . "http://$target/$database" . '"}';

    my $msg = $self->_prepare_admin_request({method  => 'POST',
					     master  => $master,
					     path    => '_replicate',
					     content => $content,
					    });
    my $res = $self->_send_request($msg);    
    my $data =  $self->_parse_result($res);
    return $data;
}
    


# Create a new document with an optional attachment.
# curl -X PUT $couchdb/$release/uuid
# curl -X PUT $couchdb/$release/uuid/attachment (if adding an attachment, too)
#   curl -X PUT http://$couchdb/$version/$uuid \
#        -d @/usr/local/wormbase/databases/WS226/cache/gene/overview/WBGene00006763.html -H "Content-Type: text/html"
# Assuming here that we are ONLY stocking our couchdb, not updating it.
sub create_document {
    my $self   = shift;
    my $params = shift;
    my $attachment = $params->{attachment};
    my $uuid       = $params->{uuid};

    my $res;
    my $msg;
    # Attachments have a different URI target
    # and must include the attachment content.
    
    if ($attachment) {
	$msg  = $self->_prepare_request({method  => 'PUT',
					 path    => "$uuid/attachment",
					 content => "$attachment" } 
	    );
    } else {
	$msg  = $self->_prepare_request({method => 'PUT',
					 path   => $uuid });
    }

    $res     = $self->_send_request($msg);
    my $data = $self->_parse_result($res);
    return $data;
}


# Check if a document exists, but don't bother parsing json.
# curl -X PUT $couchdb/$release/uuid
# curl -X GET http://127.0.0.1:5984/ws226/gene_WBGene00006763_overview
sub check_for_document {
    my $self = shift;
    my $uuid = shift;
    my $msg  = $self->_prepare_request({ method => 'GET',
					 path   => $uuid });
    my $res  = $self->_send_request($msg);
    if ($res->is_success) {
	return 1;
    } else {
	return 0;
    }
}




# Fetch a document
# curl -X PUT $couchdb/$release/uuid
# curl -X GET http://127.0.0.1:5984/ws226/gene_WBGene00006763_overview
sub get_document {
    my $self = shift;
    my $uuid = shift;
    my $msg  = $self->_prepare_request({ method => 'GET',
					 path   => $uuid });
    my $res  = $self->_send_request($msg);
    if ($res->is_success) {
	my $data = $self->_parse_result($res);
	return $data;
    } else {
	return 0;
    }
}


# GET couchdbhost/version/uuid/attachment
# Returns the HTML of the attachement; otherwise return false.
sub get_attachment {
    my $self = shift;
    my $uuid = shift;
    my $msg  = $self->_prepare_request({ method => 'GET',
					 path   => "$uuid/attachment" });
    my $res  = $self->_send_request($msg);    
    if ($res->is_success) {
	return $res->content;
    } else {
	return 0;
    }
}
	



###########################################
#
# Private Methods 
#
###########################################

#sub _encode_args {
#    my ($self, $args) = @_;
#
#    # Values need to be utf-8 encoded.  Because of a perl bug, exposed when
#    # client code does "use utf8", keys must also be encoded.
#    # see: http://www.perlmonks.org/?node_id=668987
#    # and: http://perl5.git.perl.org/perl.git/commit/eaf7a4d2
#    return { map { utf8::upgrade($_) unless ref($_); $_ } %$args };
#}

sub _prepare_request {
    my ($self,$opts) = @_;
    my $method  = $opts->{method};
    my $path    = $opts->{path};
    my $content = $opts->{content};
    my $host    = $opts->{host} || $self->couchdbmaster;
        
    my $database  = $opts->{database} || lc($self->release);

    # Prepend the database unless this is just a database request.
    my $full_path = $path ? $database . "/$path" : $database;    
    my $uri  = URI->new("http://" . $host . "/$full_path");
    my $msg  = HTTP::Request->new($method,$uri);

    # Append content to the body if it exists (this is the attachment mechanism)
    if ($content) {
	$msg->content($content);
    }

    return $msg;    
}


# No database required for admin requests.
sub _prepare_admin_request {
    my ($self,$opts) = @_;
    my $master  = $opts->{master};   # The server we are sending request to.
    my $method  = $opts->{method};
    my $path    = $opts->{path};
    my $content = $opts->{content};
        
    my $uri  = URI->new("http://$master/$path");
    my $msg  = HTTP::Request->new($method,$uri);

    # Append content to the body if it exists
    if ($content) {
	$msg->content($content);
	$msg->header('Content-Type' => 'application/json');
    }
    return $msg;    
}

sub _send_request {
    my $self    = shift;
    my $msg     = shift;
    
    my $ua = $self->ua;
    $ua->request($msg);    

}

sub _parse_result {
    my ($self, $res) = @_;
    
    my $content = $res->content;

#    my $obj = try { $self->_from_json($content) };
    my $obj = $self->_from_json($content);
    return $obj;
}


1;

