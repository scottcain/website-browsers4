package WormBase::Update::Staging::CreateJBrowseInstance;

use Moose;
extends qw/WormBase::Update/;
use Config::Tiny;
use File::Copy;
use Cwd;
use FileHandle;
use File::Basename;
use JSON;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'create jbrowse data sets',
    );

has 'jbrowse_destination' => (
    is => 'rw',
    lazy_build => 1,
    );

has 'desired_species' => (
    is => 'ro',
    );

has 'desired_bioproject' => (
    is => 'ro',
    );
   
has 'confirm_only' => (
    is => 'ro',
    );

has 'filedir' => (
    is => 'ro',
    default => '/usr/local/ftp/pub/wormbase/releases/'
    );

has 'gfffile' => (
    is => 'rw',
    );

has 'tmpdir' => (
    is => 'rw',
    );

has 'includes' => (
    is => 'rw',
    );

sub run {
    my $self = shift;

    # get a list of (symbolic g_species) names
    my $desired_species = $self->desired_species;
    my $species = [];
    if ($desired_species) {
	push @$species,$desired_species;      
    } else {
	($species) = $self->wormbase_managed_species;
    }
 
    my $release = $self->release;

    $self->setup_jbrowse_dir();

    foreach my $name (sort { $a cmp $b } @$species) {

	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	$self->log->info(uc($name). ': start');	

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {

	    if ($self->confirm_only) {
		$self->confirm_contents($bioproject);
		next;
	    }


            my $id = $bioproject->bioproject_id;
            if ($self->desired_bioproject and $id ne $self->desired_bioproject) {
                $self->log->info(  "Skipping $id; it is not the requested bioproject");
                next;
            }

	    unless ($bioproject->has_been_updated) {
		$self->log->info(  "Skipping $name; it was not updated during this release cycle");
		next;
	    }

	    $self->log->info("   Processing bioproject: $id");

            $self->run_prepare_refseqs($bioproject);
            $self->run_flatfile_to_json_names($bioproject);
            $self->run_generate_names($bioproject);
            $self->run_flatfile_to_json_nonames($bioproject);
            $self->build_tracklist($bioproject);

	}
	$self->log->info(uc($name). ': done');
    }

    $self->log->info("Finalizing JBrowse install");
    $self->cleanup();
}

sub setup_jbrowse_dir {
    my $self = shift;

    $self->log->info("This hasn't been written yet--been doing it by hand so far");
    return;

    #get JBrowse tarball, unpack

    #run ./setup.sh

    #make symlinks that will be needed
}

sub run_prepare_refseqs {
    my ($self,$bioproject) = @_;

    #fetch fasta and gff files
    my $datapath   = $self->filedir . $self->release . "/species/" . $bioproject ;
    my $fastafile  = "$bioproject.".'.'.$self->release.'.genomic.fa';

    my $tmpdir = $self->tmp_dir;

    copy("$datapath/$fastafile.gz", $tmpdir) or $copyfailed = 1;

    if ($copyfailed) {
        #used to have tool here to get the file from ft.wormbase.org, probably don't need that anymore
        die "copying fasta file for $bioproject failed";
    }

    $self->system_call("gunzip -f $tmpdir/$fastafile.gz", "unziping $tmpdir/$fastafile");
    (-e $tmpdir/$fastafile) or die "No fasta file: $tmpdir/$fastafile");

    my $command = "nice bin/prepare-refseqs.pl --fasta $tmpdir/$fastfile --out ".$self->jbrowse_destination;
    $self->system_call($command, "running prepare-refseqs for $bioproject");

    return;
}

sub run_flatfile_to_json_names {
    my ($self,$bioproject) = @_;
}

sub run_generate_names {
    my ($self,$bioproject) = @_;
}

sub run_flatfile_to_json_nonames {
    my ($self,$bioproject) = @_;
}

sub build_tracklist {
    my ($self,$bioproject) = @_;
}

sub cleanup {
    my $self = shift;

    #make the "c_elegans_simple" dataset
    #make any remaining symlinks that are required
}

sub load_gffdb {
    my ($self,$bioproject) = @_;
    
    my $release = $self->release;
    my $name    = $bioproject->symbolic_name;
        
    my $gff     = $bioproject->gff_file;       # this includes the full path.

    my $fasta   = join("/",$bioproject->release_dir,$bioproject->genomic_fasta);  # this does not.

    my $id = $bioproject->bioproject_id;

    $ENV{TMP} = $self->tmp_dir;
    my $tmp   = $self->tmp_dir;
    
    my $db   = $bioproject->mysql_db_name;

    # Passing $db here is temporary in order to create temp db names for testing
    $self->create_database($bioproject,$db);

    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $cmd;
#    if ($bioproject->gff_version == 2) {
#	# $cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";	    
#	$cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff";
#	
#    } else {	
	$cmd = "bp_seqfeature_load.pl --summary --user $user --password $pass --fast --create -T $tmp --dsn $db $gff $fasta";	
#    }
    
    # Load. Should expand error checking and reporting.
    $self->log->info("loading database via command: $cmd");
    $self->system_call($cmd,"loading GFF mysql database: $cmd");    

#    # Temporarily: let's also load GFF2 for old species
#    if ($name =~ /elegans|briggsae|brenneri|japonica|remanei|pacificus|malayi/) {
#	my $db   = $bioproject->mysql_db_name;
#	$self->create_database($bioproject);
#	
#	# elegans requires some post-proccessing
#	if ($name =~ /elegans/) {
#	    $temp_gff2 =~ s/gff3/gff2/;  # we preferentially process GFF3 but we still need to load GFF2.
#	    $temp_gff2 =~ s/annotations/GBrowse/;
#	    
#	    # Need to do some small processing for some species.
#	    $self->log->debug("processing $name ($bioproject) GFF files");
#	    
#	    # WS226: Hinxton supplies us GBrowse GFF named g_species.release.GBrowse.gff2.gz
#	    # We just need to drop the introns and assembly tag.
#	    my $output = $bioproject->release_dir . "/$name.$id.$release.GBrowse-processed.gff2.gz";
#	    # process the GFF files	
#	    # THIS STEP CAN BE SIMPLIFIED.
#	    # It should only be necessary to:
#	    #     strip CHROMOSOME_
#	    #     drop introns
#	    #     drop assembly_tag
#	    
#	    my $cmd = $self->bin_path . "/../helpers/process_gff.pl $temp_gff2 | gzip -cf > $output";
#	    $bioproject->gff_file("$output"); # Swap out the GFF files to load.
#	    $gff = $bioproject->gff_file;
#	    $self->system_call($cmd,'processing C. elegans GFF2');
#	} else {
#	    
#	    # Maybe we have a pre-prepped gff supplied by Sanger. Load that instead.
#	    my $prepped_gff = $bioproject->release_dir . "/$name.$id.$release.GBrowse.gff2.gz";
#	    if ( -e $prepped_gff) {
#		$bioproject->gff_file($prepped_gff);
#		$gff = $bioproject->gff_file;
#	    } else {
#		$gff = $temp_gff2;
#	    }
#	}
#	$cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff";
#	$self->log->info("loading database via command: $cmd");
#	$self->system_call($cmd,"loading GFF mysql database: $cmd");
#
#	# We also need to load ESTs
#	if ($name =~ /elegans/) {
#	    my $est = join("/",$bioproject->release_dir,$bioproject->ests_file);	    
#	    $self->system_call("bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null",
#			       'loading EST fasta sequence');
#	}
#    } 
    
## Need to load FASTA sequence for GFF3
##    if ($species->gff_version == 3) {
##	$self->system_call("bp_load_gff.pl -u $user -p $pass -d $db -fasta $fasta",
##			   'loading fasta sequence');
##    }    
    
    # For C. elegans, we also need to load our ESTs.
    if ($name =~ /elegans/) {           	
	my $db      = $bioproject->mysql_db_name;

#	my $gff3_db = $db . '_gff3_test';  # for now;
	$self->system_call("bp_seqfeature_load.pl --summary --user $user --password $pass --fast -T $tmp --dsn $db $fasta",
			   'loading EST fasta sequence');
    }
}



sub create_database {
    my ($self,$bioproject,$db) = @_;
    my $database = $db ? $db : $bioproject->mysql_db_name;
    
    $self->log->info("creating a new mysql GFF database: $database");
    
    my $drh  = $self->drh;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;	
    #my $host = $self->mysql_host;
    my $host = 'localhost';

    # Create the database
    $drh->func('createdb', $database, $host, $user, $pass, 'admin') or $self->log->logdie("couldn't create database $database: $!");
    
    # Grant privileges
    my $webuser = $self->web_user;
    $self->system_call("mysql -u $user -p$pass -e 'grant all privileges on $database.* to $webuser\@localhost'",
		       'creating GFF mysql database');
}


# Compress databases using myisampack
sub pack_database {
    my ($self,$bioproject) = @_;
    my $data_dir  = $self->mysql_data_dir;    
    my $target_db = $bioproject->mysql_db_name;
    $self->log->info("compressing mysql database");
    
    # Pack the database
    $self->system_call("myisampack $data_dir/$target_db/*.MYI",
		       'packing GFF mysql database');

    # Check the database
    $self->system_call("myisamchk -rq --sort-index --analyze $data_dir/$target_db/*.MYI",
		       'analyzing indexes');
}




sub check_database {
    my ($self,$bioproject) = @_;
    $self->log->debug("checking status of new database");
    
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $target_db = $bioproject->mysql_db_name;
    my $db        = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->log->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->log->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
#    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}

# Do some simple confirmation of database loads
# after the entire process has finished.
sub confirm_contents {
    my ($self,$bioproject) = @_;
            
#    my $user = $self->mysql_user;
#    my $pass = $self->mysql_pass;
    my $user = 'nobody';
    my $pass = '';
    my $host = $self->mysql_host;

    my $db   = $bioproject->mysql_db_name;
    my $dbh = DBI->connect("DBI:mysql:$db;host=$host", $user, $pass)
	|| $self->log->warn("$db is missing!!\n") && next;
    my $sth = $dbh->prepare('select count(*) from sequence') 
	|| $self->log->logdie("$DBI::errstr");
    $sth->execute();
    
    while (my $ref = $sth->fetchrow_hashref()) {
	$self->log->info("$db: " . $ref->{'count(*)'} . " sequences");
    }
    $dbh->disconnect;
}


1;

