package WormBase::Update::Staging::UnpackClustalWDatabase;

use Moose;
use DBI;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => ( is => 'ro', default => 'unpack clustal database' );

has 'clustal_sql' => ( is => 'ro', lazy_build => 1 );
sub _build_clustal_sql {
    my $self = shift;
    my $release = $self->release;
    return "wormpep_clw.$release.sql";
}

sub run {
    my $self = shift;    
    $self->log->info("unpacking the clustal database");
    
    my $release    = $self->release;
    my $release_id = $self->release_id;

    # Is this a mysqldump or just a bz2?
    my $source = join('/',$self->ftp_releases_dir,$release,'COMPARATIVE_ANALYSIS',$self->clustal_sql . '.bz2');
    my $mysql_root = $self->mysql_data_dir;

    my $tmp_dir = $self->tmp_dir;    
    chdir($tmp_dir);
    
    $self->system_call("bunzip2 -c $source > $tmp_dir/" . $self->clustal_sql,
		       "bunzipping clustalw");
    
    $self->create_database;

    $self->log->info("loading the clustal database");
    $self->load_database;        
}



sub create_database {
    my $self = shift;
    my $release = $self->release;
    $self->log->debug("creating a new clustal database: clustal_$release");
        
    my $database = "clustal_$release";
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;	
    my $host = $self->mysql_host;
    
    # Create the database
    my $drh = $self->drh;
    my $rc = $drh->func('createdb',$database, $host, $user, $pass, 'admin') or $self->log->logdie("couldn't create database $database: $!");
    
    # Grant privileges
    my $webuser = $self->web_user;
    $self->system_call("mysql -u $user -p$pass -e 'grant all privileges on $database.* to $webuser\@localhost'",
		       "creating clustal mysql database");
}
    
    
sub load_database {
    my $self = shift;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;

    my $sql = join('/',$self->tmp_dir,$self->clustal_sql);
    my $db  = 'clustal_' . $self->release;

    $self->system_call("mysql -u$user -p$pass $db < $sql",
		       "loading clustal database");
}

1;
