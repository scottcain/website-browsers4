package WormBase::Update::Development::LoadGenomicGFFDB;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use DBI;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'load genomic gff databases',
    );


has 'create_database' => (
    isa => 'DBI',
    lazy_build => 1 );

sub _build_create_database {	
    my $self = shift;
    my $database = $self->db_symbolic_name;
    
    $self->log->debug("creating a new mysql GFF database: $database");
    
    my $drh = DBI->install_driver('mysql');	
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;	
    my $host = $self->mysql_host;
    
    # Create the database
    $drh->func('createdb', $database, $host, $user, $pass, 'root') or $self->log->logdie("couldn't create database $database: $!");
    
    # Grant privileges
    my $webuser = $self->web_user;
    $self->system_call("mysql -u $user -p$pass -e 'grant all privileges on $database.* to $webuser\@localhost'",
		       "command: mysql -u $user -p$pass -e 'grant all privileges on $database.* to $webuser\@localhost'");
}


#######################################
#
# Begin Methods
#
#######################################
sub run {
    my $self    = shift;

    # get a list of (symbolic g_species) names
    my ($species) = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	$self->log->info(uc($name). ': start');	
	$self->load_gffdb($species);
	$self->check_database($species);
	$self->log->info(uc($name). ': done');	
    }
}

sub load_gffdb {
    my ($self,$species) = @_;
   
    my $release = $self->release;
    my $name    = $self->species;

    $self->create_database();

    my $gff     = $self->gff_file; 
    my $fasta   = $self->genomic_fasta;
   
    if ($species =~ /elegans/) {

	# Create the ESTs file
	$self->dump_elegans_ests;
	
	# Need to do some small processing for some species.
	$self->log->debug("processing $species GFF files");

	# process the GFF files	
	my $output = $species->release_dir . "/$name.$release.gff2.GBrowse.gz";
	my $cmd = $self->bin_path . "/helpers/process_celegans_gff.pl $release $gff | gzip -cf > $output";
	$self->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $self->gff_file;
	$self->system_call($cmd,"cmd: $cmd");
    } elsif ($species =~ /briggsae/) {
	my $output = $species->release_path . "/$species.$release.gff2.GBrowse.gz";
	my $cmd = $self->bin_path . "/helpers/process_cbriggsae_gff.pl $version $gff | gzip -cf > $output";
	$self->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $self->gff_file;
	$self->system_call($cmd,"cmd: $cmd");
    }

    $ENV{TMP} = $self->tmp_dir;
    
    my $db   = $species->db_symbolic_name;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;

    my $cmd;
    if ($self->gff_version eq '2') {
	$cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";	    
    } else {
	$cmd = "bp_seqfeature_load.pl --user $user --password $pass --create --dsn $db $gff";       
    }
    
    # Load. Should expand error checking and reporting.
    $self->log->info("loading database via command: $cmd");
    $self->system_call($cmd,"cmd: $cmd");
    
    # Need to load FASTA sequence for GFF3
    if ($self->gff_version eq '3') {
	$self->system_call("bp_load_gff.pl -u $user -p $pass -d $db -fasta $fasta",
			   "cmd: bp_load_gff.pl -u $user -p $pass -d $db -fasta $fasta");
    }    

    if ($species =~ /elegans/) {
	my $est = join("/",$species->release_dir,$species->ests_file);
	$self->system_call("gunzip $est.gz",
			   "cmd: gunzip $est.gz");
	my $pass = $self->mysql_pass;
	
	$self->system_call("bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null",
			   "cmd: bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null");
	$self->system_call("gzip $est",
			   "cmd: gzip $est");    
    }
}

# Compress databases using myisampack
sub pack_database {
    my ($self,$species) = @_;
    my $data_dir  = $self->mysql_data_dir;    
    my $target_db = $species->db_symbolic_name;
    $self->log->info("compressing mysql database");
    
    # Pack the database
    $self->system_call("myisampack $data_dir/$target_db/*.MYI",
		       "cmd: myisampack $data_dir/$target_db/*.MYI");

    # Check the database
    $self->system_call("myisamchk -rq --sort-index --analyze $data_dir/$target_db/*.MYI",
		       "cmd: myisamchk -rq --sort-index --analyze $data_dir/$target_db/*.MYI");
}




sub check_database {
    my ($self,$species) = @_;
    $self->log->debug("checking status of new database");
    
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $target_db = $self->target_db;
    my $db     = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->log->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->log->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}


1;
