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
    foreach my $name (@$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	$self->log->info(uc($name). ': start');	

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {

	    unless ($bioproject->has_been_updated) {
		$self->log->info(  "Skipping $name; it was not updated during this release cycle");
		next;
	    }

	    my $id = $bioproject->bioproject_id;
	    $self->log->info("   Processing bioproject: $id");

	    $self->load_gffdb($bioproject);
#	$self->pack_database($species);
	    $self->check_database($bioproject);
	}
	$self->log->info(uc($name). ': done');
    }
}

sub load_gffdb {
    my ($self,$bioproject) = @_;
    
    my $release = $self->release;
    my $name    = $bioproject->symbolic_name;
    
    $self->create_database($bioproject);
    
    my $gff     = $bioproject->gff_file;       # this includes the full path.
    my $fasta   = join("/",$bioproject->release_dir,$bioproject->genomic_fasta);  # this does not.

    my $id = $bioproject->bioproject_id;
    
    if ($name =~ /elegans/) {

	# HACK HACK HACK HACK - We need to use a different input
	# file until we have GFF3
	# This needs to be c_elegans.WSXXX.GBrowse.gff2.gz NOT the core GFF file (c_elegans.WSXXX.annotations.gff2.gz)
	$gff =~ s/annotations/GBrowse/;


	# Create the ESTs file
	# Now created by hinxton.
	# $self->dump_elegans_ests;
	
	# Need to do some small processing for some species.
	$self->log->debug("processing $name ($bioproject) GFF files");

	# WS226: Hinxton supplies us GBrowse GFF named g_species.release.GBrowse.gff2.gz
	# We just need to drop the introns and assembly tag.
	my $output = $bioproject->release_dir . "/$name.$id.$release.GBrowse-processed.gff2.gz";
	# process the GFF files	
	# THIS STEP CAN BE SIMPLIFIED.
	# It should only be necessary to:
	#     strip CHROMOSOME_
	#     drop introns
	#     drop assembly_tag

	# Fix the FASTA file
	my $tmp = $self->tmp_dir;
	my $reformat = "gunzip -c $fasta | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > $tmp/$name.$id.$release.genomic-renamed.fa.gz";
	$self->system_call($reformat,$reformat);
	$fasta = "$tmp/$name.$id.$release.genomic-renamed.fa.gz";

	my $cmd = $self->bin_path . "/../helpers/process_gff.pl $gff | gzip -cf > $output";
	$bioproject->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $bioproject->gff_file;
	$self->system_call($cmd,'processing C. elegans GFF');


#    } elsif ($name =~ /briggsae/) {
#
#	# This really only needs to change =~ s/CHROMOSOME_// 
#	my $output = $species->release_dir . "/$species.$release.GBrowse.gff2.gz";
#	my $cmd = $self->bin_path . "/helpers/process_gff.pl $gff | gzip -cf > $output";
#	$species->gff_file("$output"); # Swap out the GFF files to load.
#	$gff = $species->gff_file;
#	$self->system_call($cmd,'processing C. briggsae GFF');
    } else {
	# Maybe we have a pre-prepped gff supplied by Sanger. Load that instead.
	my $prepped_gff = $bioproject->release_dir . "/$name.$id.$release.GBrowse.gff2.gz";
	if ( -e $prepped_gff) {
	    $bioproject->gff_file($prepped_gff);
	    $gff = $bioproject->gff_file;
	}
    }
    
    $ENV{TMP} = $self->tmp_dir;
    my $tmp   = $self->tmp_dir;

    my $db   = $bioproject->mysql_db_name;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $cmd;
    if ($bioproject->gff_version == 2) {
	# $cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";	    
	$cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff";
    } else {
	$cmd = "bp_seqfeature_load.pl --summary --user $user --password $pass --fast --create -T $tmp --dsn $db $gff $fasta";       
#	$cmd = "bp_seqfeature_load.pl --summary --user $user --password $pass --create -T $tmp --dsn $db $gff $fasta";       
    }
    
    # Load. Should expand error checking and reporting.
    $self->log->info("loading database via command: $cmd");
    $self->system_call($cmd,"loading GFF mysql database: $cmd");
    
    # Need to load FASTA sequence for GFF3
#    if ($species->gff_version == 3) {
#	$self->system_call("bp_load_gff.pl -u $user -p $pass -d $db -fasta $fasta",
#			   'loading fasta sequence');
#    }    
    
    # For C. elegans, we also need to load our ESTs.
    # Should probably also generate GFF patches here and load.
    if ($name =~ /elegans/) {
	my $est = join("/",$bioproject->release_dir,$bioproject->ests_file);
	my $pass  = $self->mysql_pass;
	
	$self->system_call("bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null",
			   'loading EST fasta sequence');
    }
}



sub create_database {
    my ($self,$bioproject) = @_;
    my $database = $bioproject->mysql_db_name;
    
    $self->log->debug("creating a new mysql GFF database: $database");
    
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
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}


1;
