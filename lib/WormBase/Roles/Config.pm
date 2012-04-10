package WormBase::Roles::Config;

# Shared configuration for WormBase administration.

use Moose::Role;
use Ace;
use Net::OpenSSH;

####################################
#
# The Production Manager
#
####################################

has 'production_manager' => ( is => 'ro', default => 'tharris') ;

sub ssh {
    my ($self,$node) = @_;
    my $manager = $self->production_manager;
    my $ssh = Net::OpenSSH->new("$manager\@$node");
    $ssh->error and die "Can't ssh to $manager\@$node: " . $ssh->error;	
    return $ssh;
}

# The precache_host is the host we will send queries to.
# Typically, this would be the staging server as it will
# have the newest version of the database.

####################################
#
# Precaching
# cache_query_host is where precache queries
# are sent. The app configruration of that
# host(s) controls in which couchdb the data
# is stored.
#
####################################

# Prewarming the cache, we simply direct request to the app on localhost.
# The precache script can set this as appropriate to allow caching
# of the production site at a low level.
has 'cache_query_host_staging'    => ( is => 'rw', default => 'http://staging.wormbase.org');
has 'cache_query_host_production' => ( is => 'rw', default => 'http://www.wormbase.org');
has 'cache_query_host_classic'    => ( is => 'rw', default => 'http://localhost:8080');


####################################
#
# Couch DB
# Note that SOME of these parameters
# are in conflict with app-level
# configuration.
#
####################################

# Where our couchdb data directory lives.
has 'couchdb_root'      => ( is => 'rw', default => '/usr/local/wormbase/couchdb' );

# couchdbmaster 
# We precache directly to our production host. Not sure how intelligent this is.
# This works because the staging database is +1 that in production.
# Meanwhile, production sites can continue to cache to production database.

has 'couchdb_host_staging'     => ( is => 'rw', default => '206.108.125.164:5984' );
has 'couchdb_host_production'  => ( is => 'rw', default => '23.21.171.141:5984');

# Subtly different than production, the master host is that used for replication.
has 'couchdb_host_master'     => ( is => 'rw', default => '23.21.171.141:5984' );

# Each server gets its own couch.
# See ReplicateCouchDB. If reads/writes to couch become a bottleneck
# reinstate this.
has 'local_couchdb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/206.108.125.165
            206.108.125.164
            206.108.125.163
            206.108.125.162
            206.108.125.166/],
    },
    );

has 'remote_couchdb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/canopus.caltech.edu/]},
    );

####################################
#
# WormBase user database config
#
####################################

has 'wormbase_user_host'     => ( is => 'rw', default => '23.21.171.141' );
has 'wormbase_user_username'     => ( is => 'rw', default => 'wormbase' );
has 'wormbase_user_db'     => ( is => 'rw', default => 'wormbase_user' );


####################################
#
# WormBase root, tmp dir, acedmp dir, support dbs
#
####################################

# The full wormbase root (NOT the app root)
has 'wormbase_root'   => ( is => 'ro', default => '/usr/local/wormbase');

# The staging directory that serves staging.wormbase.org. Will be mirrored into production.
has 'app_staging_dir' => ( is => 'ro', default => '/usr/local/wormbase/website/staging');


has 'tmp_dir'       => ( is => 'ro', lazy_build => 1 );			 
sub _build_tmp_dir {
    my $self = shift;
    my $dir = $self->wormbase_root . "/tmp/staging";
    $self->_make_dir($dir);
    return $dir;
}

has 'acedmp_dir'       => ( is => 'ro', lazy_build => 1 );          
sub _build_acedmp_dir {
    my $self = shift;
    my $dir = $self->tmp_dir . "/acedmp";
    $self->_make_dir($dir);
    return $dir;
}

has 'support_databases_dir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_support_databases_dir {
    my $self = shift;
    my $dir  = $self->wormbase_root . "/databases";
    $self->_make_dir($dir);

    # Create support db dirs, too.
    my @directories = qw/blast blat ontology tiling_array interaction orthology position_matrix gene/;
    my $release     = $self->release;    
    $self->_make_dir("$dir/$release");
    
    foreach (@directories) {
	$self->_make_dir("$dir/$release/$_");
    }
    
    return $dir;
}


has 'dbh' => (
    is => 'ro',
    lazy_build => 1);

sub _build_dbh {
    my $self = shift;
    my $acedb   = $self->acedb_root;
    my $dbh     = Ace->connect(-host => 'localhost',-port => '2005') or $self->log->logdie("couldn't open ace:$!");
    return $dbh;
}


has 'release' => (
    is        => 'rw',
#    lazy_build => 1,
    );

#around 'release' => sub {
#    my $orig   = shift;
#    my $self   = shift;
#
#    my $release = $self->$orig();
#    return $release if $release;
#
#    # If not provided, then we need to fetch it from Acedb.
#    my $dbh = $self->dbh;
#    return $dbh->version;
#};

has 'production_release' => (
    is        => 'rw',
#    lazy_build => 1,
    );

around 'production_release' => sub {
    my $orig   = shift;
    my $self   = shift;

    # We may have supplied a specific release
    my $release = $self->release;
    return $release if $release;

    $release = $self->$orig();
    return $release if $release;

    # If not provided, then we need to fetch it from Acedb.
    my $dbh = Ace->connect(-host=>'50.19.229.229',-port=>'2005');    
    return $dbh->version;
};




# target and target_nodes: symbolic names of production, development, mirror
# Used when pushing a staged release to other nodes.
has 'target' => (
    is        => 'rw',
#    lazy_build => 1,
    );

around 'target' => sub {
    my $orig   = shift;
    my $self   = shift;

    my $target = $self->$orig();

    die unless ($target =~ /^(production|development|mirror|staging|new)$/);
    return $target;
};


# Return nodes that should require specific components.
# Should be one of support, mysql, acedb.
# Will call a corresponding method of "production_support_nodes", eg.
has 'target_nodes' => (
    is => 'rw',
    );

around 'target_nodes' => sub {
    my $orig = shift;
    my $self = shift;
    my $type = shift;

    die "Available target types should be one of: acedb, mysql, support, app\n" unless 
	($type =~ /^(acedb|mysql|support|app)$/);
    
    my $target = $self->target;
    my $method = join('_',$target,$type,'nodes');
    return $self->$method;
};



sub release_id {
    my $self    = shift;
    my $release = $self->release;
    $release =~ /WS(.*)/ if $release;
    return $1;
} 


####################################
#
# AceDB
#
####################################

has 'acedb_root' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_acedb_root {
    my $self = shift;
    return $self->wormbase_root . "/acedb";
}

has 'acedb_group' => (
    is => 'ro',
    default => 'acedb' );


has 'acedb_user' => (
    is => 'ro',
    default => 'acedb' );



####################################
#
# MYSQL
#
####################################

has 'drh' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_drh {	
    my $self = shift;       
    my $drh = DBI->install_driver('mysql');
    return $drh;
}


has 'mysql_data_dir' => ( is => 'ro',  default => '/usr/local/mysql/data' );
has 'mysql_user'     => ( is => 'ro',  default => 'root'      );
has 'mysql_pass'     => ( is => 'ro',  default => '3l3g@nz'   );
has 'mysql_host'     => ( is => 'ro',  default => 'localhost' );


####################################
#
# Local FTP
#
####################################

has 'ftp_root' => (
    is      => 'ro',
    default => '/usr/local/ftp/pub/wormbase'
    );

# The releases/ directory
has 'ftp_releases_dir' => (
    is         => 'ro',
    lazy_build => 1,
    );

# Where the production FTP site lives.
# Assumes that the user running the update script
# has access and that the ftp_root is the 
# same as above.
has 'production_ftp_host' => (
    is         => 'ro',
    default    => 'wb-dev.oicr.on.ca',
    );

sub _build_ftp_releases_dir {
    my $self = shift;
    return $self->ftp_root . "/releases";
}

# The releases/ directory
has 'ftp_database_tarballs_dir' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_ftp_database_tarballs_dir {
    my $self = shift;
    return $self->ftp_root . "/releases";
}


# This is the VIRTUAL species directory at /species
has 'ftp_species_dir' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_ftp_species_dir {
    my $self = shift;    
    return $self->ftp_root . "/species";
}

####################################
#
# Remote FTP
#
####################################

has 'remote_ftp_server' => (
    is => 'ro',
    default => 'ftp.sanger.ac.uk',
    );

has 'contact_email' => (
    is => 'ro',
    default => 'todd@wormbase.org',
    );
    
has 'remote_ftp_root' => (
    is => 'ro',
    default => 'pub2/wormbase'
    );

has 'remote_ftp_releases_dir' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_remote_ftp_releases_dir {
    my $self = shift;
#    return $self->remote_ftp_root . "/releases.test";
    return $self->remote_ftp_root . '/releases';
}


has 'staging_host' => (
    is => 'ro',
    default => 'wb-web7.oicr.on.ca' );


####################################
#
# Production related configuration
#
####################################

# The WormBase NFS server.
has 'local_nfs_server' => (
    is => 'ro',
    default => 'wb-web1.oicr.on.ca'
    );

has 'local_nfs_root' => (
    is => 'ro',
    default => '/usr/local/wormbase/shared',
    );



###############
# APP NODES
###############
has 'staging_app_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-web1.oicr.on.ca
            wb-web2.oicr.on.ca
            wb-web3.oicr.on.ca
            wb-web4.oicr.on.ca
/]},
    );

# GBrowse node managed independently.
#            wb-gb1.oicr.on.ca

has 'production_app_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/50.19.112.56
            ec2-50-19-229-229.compute-1.amazonaws.com
            wb-mining.oicr.on.ca
	 canopus.caltech.edu/]},
    );


###############
# ACEDB NODES
###############
has 'staging_acedb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-web7.oicr.on.ca
            wb-web1.oicr.on.ca
            wb-web2.oicr.on.ca
	    wb-web3.oicr.on.ca
	    wb-web4.oicr.on.ca/]
    },
    );

has 'development_acedb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-dev.oicr.on.ca/]
    },
    );

has 'caltech_acedb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/canopus.caltech.edu/],
    },
    );

has 'production_acedb_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/ec2-50-19-229-229.compute-1.amazonaws.com
	    wb-mining.oicr.on.ca
            canopus.caltech.edu/],
    },
    );

#            wb-web1.oicr.on.ca
#            wb-web2.oicr.on.ca
#	    wb-web3.oicr.on.ca
#	    wb-web4.oicr.on.ca


###############
# SUPPORT NODES
###############
has 'staging_support_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-web7.oicr.on.ca
            wb-web1.oicr.on.ca
            wb-web2.oicr.on.ca
	    wb-web3.oicr.on.ca
	    wb-web4.oicr.on.ca/]
    },
    );

has 'development_support_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-dev.oicr.on.ca/]
    },
    );

has 'production_support_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/ec2-50-19-229-229.compute-1.amazonaws.com
            wb-mining.oicr.on.ca
            canopus.caltech.edu
/],
    },
    );

#            wb-web1.oicr.on.ca
#            wb-web2.oicr.on.ca
#	    wb-web3.oicr.on.ca
#	    wb-web4.oicr.on.ca



###############
# MYSQL NODES
###############
has 'staging_mysql_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-web7.oicr.on.ca
            wb-web1.oicr.on.ca
            wb-web2.oicr.on.ca
	    wb-web3.oicr.on.ca
	    wb-web4.oicr.on.ca/],
    },
    );

has 'development_mysql_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/wb-dev.oicr.on.ca/],
    },
    );

has 'production_mysql_nodes' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
	[qw/ec2-50-19-229-229.compute-1.amazonaws.com
            wb-gb1.oicr.on.ca
            wb-mining.oicr.on.ca
            canopus.caltech.edu
/],
    },
    );
#            wb-web1.oicr.on.ca
#            wb-web2.oicr.on.ca
#	    wb-web3.oicr.on.ca
#	    wb-web4.oicr.on.ca


####################################
#
# Available species
#
####################################

# A discoverable list of species (symbolic) names.
# We use the /species directory since it may contain
# species that aren't part of WormBase proper.
has 'all_available_species' => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1 );

sub _build_all_available_species {
    my $self = shift;
    my $species_dir = $self->ftp_species_dir;
    opendir(DIR,"$species_dir") or $self->log->logdie("Couldn't open the species directory ($species_dir) on the FTP site.");
    my @species = grep { !/^\./ && -d "$species_dir/$_" } readdir(DIR);
    return \@species;
}

# A dsicoverable list of species (symbolic) names.
# distributed in the latest release.
has 'wormbase_managed_species' => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
    );

sub _build_wormbase_managed_species {
    my $self = shift;
    my $release = $self->release;
    my $species_path = join("/",$self->ftp_releases_dir,$release,'species');
    opendir(DIR,"$species_path") or die "Couldn't open the species directory ($species_path) on the FTP site.";
    my @species = grep { !/^\./ && -d "$species_path/$_" } readdir(DIR);
    return \@species;
}
    


# A discoverable list of releases.
# Used mostly for automatic mirroring
# since it many installations I do not 
# want to have to mirror all releases.
has 'existing_releases' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_existing_releases {
    my $self = shift;
    my $releases = $self->ftp_releases_dir;
    opendir(DIR,"$releases") or $self->log->logdie("Couldn't open the releases directory ($releases) on the FTP site.");
    my @releases = sort { $a cmp $b } grep { /^WS/ } grep { !/^\./ && -d "$releases/$_" } readdir(DIR);    
    return \@releases;
}


sub _reset_dir {
    my ($self,$target) = @_;
        
    $target =~ /\S+/ or return;
    
#    $self->_remove_dir($target) or return;
    $self->_make_dir($target) or return;    
    return 1;
}

sub _remove_dir {
    my ($self,$target) = @_;

    $target =~ /\S+/ or return;
    $self->log->error("trying to remove $target directory which doesn't exist") unless -e $target;
    system ("rm -rf $target") or $self->log->warn("couldn't remove the $target directory");
    return 1;
}

sub _make_dir {
  my ($self,$target) = @_;
  
  $target =~ /\S+/ or return;
  if (-e $target) {
    return 1;
  }
  mkdir $target, 0775;
  return 1;
}



1;
