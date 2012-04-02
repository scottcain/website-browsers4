package WormBase::CouchDB;

# Simple class for interacting with our CouchDB.
# Currently only supports creating databases,
# adding and fetching documents.  Document deletes
# and updates not yet supported.
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

has 'couchdb_host' => (
    is => 'rw',
    default => sub {
	my $self = shift;
	my $host = $self->couchdb_host_master;
	return $host;
    },
    );

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
    my $database = shift;

    my $msg;

    # trying to create a database on a different target
    if ($database) {	
	$msg  = $self->_prepare_request({method   => 'PUT',
					 database => "$database",
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
    my $master = $self->couchdb_host_master;
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


# Delete a record and all it's attachments.
sub delete_document {
    my $self   = shift;
    my $params = shift;
    my $uuid   = $params->{uuid};

    # Have to fetch the revision first. What a pain.
    my $current_version = $self->get_document($uuid);
    return unless $current_version;
    my $rev = $current_version->{_rev};
    my $msg  = $self->_prepare_request({method => 'DELETE',
					path   => $uuid,
					rev    => $rev,
				       });
    my $res  = $self->_send_request($msg);
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
					  path   => $uuid,
					  });
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



#### NOT DONE

=pod

# Read through an HTML directory to do a bulk insert of documents.
sub do_bulk_insert {
    my $self           = shift;
    my $html_directory = shift;

    my $bulksize = 1000; # number of documents to insert at a go.

    # Read through the directory, bulksize at a time.
    opendir(my $dh, $html_directory) || $self->log->warn("Couldn't open the html cache directory for reading");
    my $seen = 0;
    my @prepped_docs;

    while (my $file = readdir $dh) {
	$seen++;

	# extract the uuid.
	my $uuid = $file;
	$uuid =~ s/\.html//;

	# The attachment is the content of the file. Does this work?
	my $attachment = `cat $html_directory/$file`;

	push @prepped_docs,qq|{"_id":"$uuid","data":"$attachment"}|;

	# We've seen enough. Let's load 'em up.
	if ($seen == $bulksize) {
	    my $doc = '{"docs":[';
	    
          -----
    
    my $res;
    my $msg;
    # Attachments have a different URI target
    # and must include the attachment content.
    
	$msg  = $self->_prepare_request({method  => 'PUT',
					 path    => "$uuid/attachment",
					 content => "$attachment" } 
	    );

}

=cut

=pod 

#!/bin/sh -e

# usage: time benchbulk.sh
# it takes about 30 seconds to run on my old MacBook with bulksize 1000

BULKSIZE=100
DOCSIZE=10
INSERTS=10
ROUNDS=10
DBURL="http://127.0.0.1:5984/benchbulk"
POSTURL="$DBURL/_bulk_docs"

function make_bulk_docs() {
  ROW=0
  SIZE=$(($1-1))
  START=$2
  BODYSIZE=$3  
  
  BODY=$(printf "%0${BODYSIZE}d")

  echo '{"docs":['
    while [ $ROW -lt $SIZE ]; do
    printf '{"_id":"%020d", "body":"'$BODY'"},' $(($ROW + $START))
    let ROW=ROW+1
  done
  printf '{"_id":"%020d", "body":"'$BODY'"}' $(($ROW + $START))
  echo ']}'
}


echo "Making $INSERTS bulk inserts of $BULKSIZE docs each"

echo "Attempt to delete db at $DBURL"
curl -X DELETE $DBURL -w\\n

echo "Attempt to create db at $DBURL"
curl -X PUT $DBURL -w\\n

echo "Running $ROUNDS rounds of $INSERTS concurrent inserts to $POSTURL"
RUN=0
while [ $RUN -lt $ROUNDS ]; do

  POSTS=0
  while [ $POSTS -lt $INSERTS ]; do
    STARTKEY=$[ POSTS * BULKSIZE + RUN * BULKSIZE * INSERTS ]
    echo "startkey $STARTKEY bulksize $BULKSIZE"
    DOCS=$(make_bulk_docs $BULKSIZE $STARTKEY $DOCSIZE)
    # echo $DOCS
    echo $DOCS | curl -T - -X POST $POSTURL -w%{http_code}\ %{time_total}\ sec\\n >/dev/null 2>&1 &
    let POSTS=POSTS+1
  done

  echo "waiting"
  wait
  let RUN=RUN+1
done

curl $DBURL -w\\n

=cut
	



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
    my $host    = $self->couchdb_host || $self->couchdb_host_master;   
        
    my $database  = $opts->{database} || lc($self->release);

    # Prepend the database unless this is just a database request.
    my $full_path = $path ? $database . "/$path" : $database;    
    my $uri  = URI->new("http://" . $host . "/$full_path");

    # We need to attach the revision if this is a delete.
    if ($method eq 'DELETE') {
	my $rev = $opts->{rev};
	$uri .= "?rev=$rev";

    }
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

