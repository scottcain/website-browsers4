package WormBase::Update::Production::PushSupportDatabases;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'push support databases to production',
    );


sub run {
    my $self = shift;
    
    # get a list of nodes
    my ($nodes) = $self->local_support_database_nodes;

    # $self->package_database();

    foreach my $node (@$nodes) {
	# Three approaches:
	# 1. Rsync a tgz
	# $self->rsync_package($node);

	# 2. Keep the whole directory in sync.
	# (current approach; run as cron)
	$self->rsync_database_dir($node);

	# 3. Rsync a single database directory
	# $self->rsync_single_release($node);
    }
}


sub package_database {
    my $self        = shift;
    my $tmp_dir     = $self->tmp_dir;
    my $source_root = $self->support_databases_dir;
    my $release     = $self->release;
    my $database    = "support_databases.$release";
    chdir($tmp_dir);
    if (-e "$database.tgz") { 
	$self->log->info("support dbs have already been packaged; returning") && return;
    }

    $self->log->debug("creating tgz of support databases for $database");
    
    # We change directory to the source root to package wormbase_WSXXX without leading directories.
    $self->system_call("tar -czf $database.tgz -C $source_root $database",
		       'packaging support database dir');
    $self->log->debug("creating tgz of support databases $database: done");
    
    $self->create_md5($tmp_dir,"$database");
}

sub rsync_package { 
    my $self      = shift;
    my $release  = $self->release;
    my $database = "wormbase_$release";
    my $acedb_package = $self->tmp_dir . "/$database.tgz";

}


sub rsync_database_dir {
    my ($self,$node) = @_;
    my $root = $self->support_databases_dir;
    $self->log->info("rsyncing all (unpacked) support databases to $node");

    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' $root/ $node:$root/",
	'rsyncing support database directory');

    $self->log->info("rsyncing all (unpacked) support databases to $node");
}

sub rsync_single_release {
    my ($self,$node) = @_;
    my $root = $self->acedb_root;
    my $database   = "$root/" . $self->release;
    $self->log->info("rsyncing $database to $node");

    $self->system_call("rsync --rsh=ssh -Cav --exclude '*bak*' $database $node:$root/","rsyncing $database to $node");
    $self->log->info("rsyncing $database to $node: done");
}


# Not necessary here.
sub fix_permissions { 
    my ($self,$node) = @_;
    my $acedb_root = $self->acedb_root;
    
    $self->system_call("cd $acedb_root; pwd; chgrp -R acedb wormbase_* ; chmod 666 wormbase_*/database/block* wormbase_*/database/log.wrm wormbase_*/database/serverlog.wrm ; rm -rf wormbase_*/database/readlocks",
		       'fixing acedb permissions');
        
}




1;
