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

# Simple accessor/getter for species so I don't have to pass it around.
has 'species' => (
    is => 'rw'
    );

has 'db_symbolic_name' => (
    is => 'rw',
    lazy_build => 1 );

sub _build_db_symbolic_name {
    my $self    = shift;
    my $species = shift;
    my $version = $self->version;
    return $species . '_' . $version;
}

# Discover the name of the GFF file and its version.
has 'gff_file' => (
    is => 'rw',
    lazy_build => 1
);

sub _build_gff_file {
    my $self = shift;
    my $species = $self->species;
    my $version = $self->version;	
    my $gff = join("/",$self->ftp_species_path,$species,"$species.$version.gff2.gz");
    if (-e $gff) {
	$self->gff_version('2');
    } else {
	$gff = join("/",$self->ftp_species_path,$species,"$species.$version.gff3.gz");
	if (-e $gff) {
	    $self->gff_version('3');
	}
    }
    $self->log->logdie("Couldn't find a suitable GFF file for $species!") unless $gff;
    return $gff;
}


# Where the GFF resides
# Only really necessary for C. elegans which we post-process
has 'gff_path' => (
    is => 'rw',
    lazy_build => 1
);

sub _build_gff_path {
    my $self = shift;
    my $species = $self->species;
    my $version = $self->version;	
    my $gff = join("/",$self->ftp_species_path,$species,"$species.$version.gff2.gz");
    if (-e $gff) {
	return join("/",$self->ftp_species_path,$species);
    } else {
	$gff = join("/",$self->ftp_species_path,$species,"$species.$version.gff3.gz");
	if (-e $gff) {
	return join("/",$self->ftp_species_path,$species);
	}
    }
    return;
}
        
has 'gff_version' => (
    is      => 'rw',
    default => '2',
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
    system "mysql -u $user -p$pass -e 'grant all privileges on $database.* to $webuser\@localhost'";
}


#######################################
#
# Begin Methods
#
#######################################
sub run {
    my $self    = shift;
    my @species = $self->species_list;

    my $version = $self->version;
    my $msg     = 'building genomic GFF database for';
    foreach my $species (@species) {
	$self->log->debug("begin: $msg $species");
	$self->species($species);
	$self->load_gffdb();
	$self->check_db();
	$self->log->debug("end: $msg $species");
    }
}

sub load_gffdb {
    my $self = shift;
   
    my $version = $self->version;
    my $species = $self->species;

    $self->create_database() unless $self->dryrun;

    my $gff     = $self->gff_file; 
    my $fasta   = $self->fasta_path;
   
    if ($species =~ /elegans/) {

	# Create the ESTs file
	$self->dump_elegans_ests;
	
	# Need to do some small processing for some species.
	$self->log->debug("processing $species GFF files");

	# process the GFF files	
	my $output = $self->gff_path . "/$species.$release.gff.GBrowse.gz";
	my $cmd = $self->bin_path . "/helpers/process_celegans_gff.pl $version $gff | gzip -cf > $output";
	$self->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $self->gff_file;
	system($cmd) && $self->log->logdie("Something went wrong processing the GFF files: $!") unless $self->dryrun;	    
    } elsif ($species =~ /briggsae/) {
	my $output = $self->gff_path . "/$species.$release.gff.GBrowse.gz";
	my $cmd = $self->bin_path . "/helpers/process_cbriggsae_gff.pl $version $gff | gzip -cf > $output";
	$self->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $self->gff_file;
	system($cmd) && $self->log->logdie("Something went wrong processing the GFF files: $!") unless $self->dryrun;	    
    }

    $ENV{TMP} = $self->tmp_staging_path;
    
    my $db   = $self->db_symbolic_name;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;

    my $cmd;
    unless ($self->dryrun) {
	if ($self->gff_version eq '2') {
	    $cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";	    
	} else {
	    $cmd = "bp_seqfeature_load.pl --user $user --password $pass --create --dsn $db $gff";       
	}
   
	# Load. Should expand error checking and reporting.
	$self->log->debug("loading database via command: $cmd");
	system($cmd) && $self->log->logdie("Something went wrong loading $db: $!");
        
	# Need to load FASTA sequence for GFF3
	if ($self->gff_version eq '3') {
	    system("bp_load_gff.pl -u $user -p $pass -d $db -fasta $fasta")
		&& $self->log->logdie("Something went wrong long fasta sequence into $db: $!");
	}


	if ($species =~ /elegans/) {
	    my $custom_filename  = $self->get_filename('est_archive',$species);
	    my $est =join("/",$self->ftp_species_path,$species,"$species.$version.ests.fa");
	    system("gunzip $est.gz");
	    my $pass = $self->mysql_pass;
	    my $result = system "bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null";
	    system("gzip $est");
	}

    }
}

# Compress databases using myisampack
sub pack_database {
    my $self = shift;
    my $data_dir = $self->mysql_data_dir;    
    my $target_db = $self->target_db;
    
    # Pack the database
    system("myisampack $data_dir/$target_db/*.MYI");

    # Check the database
    system("myisamchk -rq --sort-index --analyze $data_dir/$target_db/*.MYI");
}




sub check_database {
    my ($self,$species) = @_;
    $self->logit->debug("checking status of new database");
    
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $target_db = $self->target_db;
    my $db     = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->logit->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->logit->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}


1;
