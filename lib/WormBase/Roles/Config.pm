package WormBase::Roles::Config;

# Shared configuration for WormBase administration.

use Moose::Role;

####################################
#
# WormBase root, tmp dir, support dbs
#
####################################

has 'wormbase_root' => ( is => 'ro', default => '/usr/local/wormbase');

has 'tmp_dir'       => ( is => 'ro', lazy_build => 1 );
			 
sub _build_tmp_dir {
    my $self = shift;
    return $self->wormbase_root . "/tmp/staging";
}

has 'support_databases_dir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_support_databases_dir {
    my $self = shift;
    return $self->wormbase_root . "/databases";
}


has 'release' => (
    is        => 'rw',
    );

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

has 'mysql_data_dir' => ( is => 'ro',  default => '/usr/local/mysq/data' );
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

sub _build_ftp_releases_dir {
    my $self = shift;
    return $self->ftp_root . "/releases.test";
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
    return $self->remote_ftp_root;
}



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
    lazy_build => 1 );

sub _build_all_available_species {
    my $self = shift;
    my $species_dir = $self->ftp_species_dir;
    opendir(DIR,"$species_dir") or $self->log->die("Couldn't open the species directory ($species_dir) on the FTP site.");
    my @species = grep { !/^\./ && -d "$species_dir/$_" } readdir(DIR);
    return @species;
}

# A dsicoverable list of species (symbolic) names.
# distributed in the latest release.
has 'wormbase_managed_species' => (
    is => 'ro',
    lazy_build => sub {
	my $self = shift;
	my $release = $self->release;
	my $species_path = join("/",$self->ftp_releases_dir,$release,'species');
	opendir(DIR,"$species_path") or die "Couldn't open the species directory ($species_path) on the FTP site.";
	my @species = grep { !/^\./ && -d "$species_path/$_" } readdir(DIR);
	return @species;
	},
    );


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
    opendir(DIR,"$releases") or $self->log->die("Couldn't open the releases directory ($releases) on the FTP site.");
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
    $self->logit->warn("trying to remove $target directory which doesn't exist") unless -e $target;
    system ("rm -rf $target") or $self->logit->warn("couldn't remove the $target directory");
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
