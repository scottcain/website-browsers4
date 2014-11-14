package WormBase::Update::Staging::LoadGenomicGFFDB;

use Moose;
use DBI;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'load genomic gff databases',
    );

has 'desired_species' => (
    is => 'ro',
    );
   
has 'confirm_only' => (
    is => 'ro',
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
    foreach my $name (sort { $a cmp $b } @$species) {

	# Temporary: already built.
#	next if $name =~ /suum/;
#	next if $name =~ /xylophilus/;
#	next if $name =~ /angaria/;
#	next if $name =~ /briggsae/;
#	next unless $name =~ /malayi|brenneri/;
#	next unless $name =~ /immitis|bacteriophora|loa|hapla|incognita|redivivus/;
#	next if $name =~ /suum|xylophilus|angaria|c_sp5|c_sp11/;
#	next unless $name =~ /redivivus|ratti|spiralis|suis|pacificus|exspectatus|volvulus|americanus|incognita|hapla|loa|contortus/;
	next if $name =~ /elegans/;
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
	    unless ($bioproject->has_been_updated) {
		$self->log->info(  "Skipping $name; it was not updated during this release cycle");
		next;
	    }

	    my $id = $bioproject->bioproject_id;
	    $self->log->info("   Processing bioproject: $id");

	    $self->load_gffdb($bioproject);
#	$self->pack_database($species);
	    $self->check_database($bioproject);
	    $self->confirm_contents($bioproject);
	}
	$self->log->info(uc($name). ': done');
    }
}

sub load_gffdb {
    my ($self,$bioproject) = @_;
    
    my $release = $self->release;
    my $name    = $bioproject->symbolic_name;
        
    my $gff     = $bioproject->gff_file;       # this includes the full path.

    my $fasta   = join("/",$bioproject->release_dir,$bioproject->genomic_fasta);  # this does not.

    my $id = $bioproject->bioproject_id;

#    # Also need to load GFF2 for now.
#    my $temp_gff2;
#    if ($name =~ /elegans|briggsae|brenneri|japonica|remanei|pacificus|malayi/) {
#	$temp_gff2 = $gff;
#    }

#    # WS239 ONLY: reorder GFF3
#    if ($name =~ /elegans|briggsae|brenneri|japonica|remanei|pacificus|malayi/) {
#	$self->log->debug("processing $name ($bioproject) GFF files");
#	
#	my $output = $bioproject->release_dir . "/$name.$id.$release.annotations-sorted.gff3.gz";
#	
#	my $bin_path = $self->bin_path;
#	my $cmd = "gunzip -c $gff | $bin_path/../helpers/sort_gff3.pl | gzip -cf > $output";
#	$bioproject->gff_file("$output"); # Swap out the GFF files to load.
#	$gff = $bioproject->gff_file;
#	$self->system_call($cmd,'sorting GFF3 files');	
#    }

    # Need to strip some entries from C. elegans
    # We'll process GFF3 (for now) below.
    if ($name =~ /elegans/) {	
	# Fix the FASTA file
	my $tmp = $self->tmp_dir;
	my $reformat = "gunzip -c $fasta | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > $tmp/$name.$id.$release.genomic-renamed.fa.gz";
	$self->system_call($reformat,$reformat);
	$fasta = "$tmp/$name.$id.$release.genomic-renamed.fa.gz";
    }
    
    $self->log->debug("processing $name ($bioproject) GFF files");
    my $output = $bioproject->release_dir . "/$name.$id.$release.annotations-processed.gff3.gz";
    my $cmd = $self->bin_path . "/../helpers/process_gff.pl $gff | gzip -cf > $output";
    $bioproject->gff_file("$output"); # Swap out the GFF files to load.
    $gff = $bioproject->gff_file;
    $self->system_call($cmd);	

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
    my $host = $self->mysql_host;

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

