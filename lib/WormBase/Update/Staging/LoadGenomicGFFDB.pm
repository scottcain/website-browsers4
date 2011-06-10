package WormBase::Update::Staging::LoadGenomicGFFDB;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use DBI;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'load genomic gff databases',
    );


sub run {
    my $self = shift;

    # get a list of (symbolic g_species) names
    my ($species) = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	# Some conditionals used when debugging this module.
	# This step should be parameterized to accept a species.
#	next unless $name eq 'c_elegans';
#	next if $name eq 'b_malayi';
#	next if $name eq 'c_angaria';
#	next if $name eq 'c_briggsae';
#	next if $name eq 'c_brenneri';
#	next if $name eq 'c_remanei';
#	next if $name eq 'c_japonica';
#	next if $name eq 'c_sp11';
#	next if $name eq 'c_sp7';
#	next if $name eq 'c_sp9';
#	next if $name eq 'h_contortus';
#	next if $name eq 'm_hapla';

	$self->log->info(uc($name). ': start');	
	$self->load_gffdb($species);
#	$self->pack_database($species);
	$self->check_database($species);
	$self->log->info(uc($name). ': done');	
    }
}

sub load_gffdb {
    my ($self,$species) = @_;
    
    my $release = $self->release;
    my $name    = $species->symbolic_name;
    
    $self->create_database($species);
    
    my $gff     = $species->gff_file;       # this includes the full path.
    my $fasta   = join("/",$species->release_dir,$species->genomic_fasta);  # this does not.
    if ($name =~ /elegans/) {

	# Create the ESTs file
	# Now created by hinxton.
	# $self->dump_elegans_ests;
	
	# Need to do some small processing for some species.
	$self->log->debug("processing $name GFF files");
	
	# WS226: Hinxton supplies us GBrowse GFF named g_species.release.GBrowse.gff2.gz
	# We just need to drop the introns and assembly tag.
	my $output = $species->release_dir . "/$name.$release.GBrowse-processed.gff2.gz";
	# process the GFF files	
	# THIS STEP CAN BE SIMPLIFIED.
	# It should only be necessary to:
	#     strip CHROMOSOME_
	#     drop introns
	#     drop assembly_tag

	# Fix the FASTA file
	my $tmp = $self->tmp_dir;
	my $reformat = "gunzip -c $fasta | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > $tmp/$name.$release.genomic-renamed.fa.gz";
	$self->system_call($reformat,$reformat);
	$fasta = "$tmp/$name.$release.genomic-renamed.fa.gz";

	my $cmd = $self->bin_path . "/../helpers/process_gff.pl $gff | gzip -cf > $output";
	$species->gff_file("$output"); # Swap out the GFF files to load.
	$gff = $species->gff_file;
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
	my $prepped_gff = $species->release_dir . "/$name.$release.GBrowse.gff2.gz";
	if ( -e $prepped_gff) {
	    $species->gff_file($prepped_gff);
	    $gff = $species->gff_file;
	}
    }
    
    $ENV{TMP} = $self->tmp_dir;
    my $tmp   = $self->tmp_dir;

    my $db   = $species->db_symbolic_name;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $cmd;
    if ($species->gff_version == 2) {
	# $cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";	    
	$cmd = "bp_bulk_load_gff.pl --user $user --password $pass -c -d $db --fasta $fasta $gff";
    } else {
	$cmd = "bp_seqfeature_load.pl --user $user --password $pass --fast --create -T $tmp --dsn $db $gff $fasta";       
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
	my $est = join("/",$species->release_dir,$species->ests_file);
	my $pass = $self->mysql_pass;
	
	$self->system_call("bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null",
			   'loading EST fasta sequence');
    }
}



sub create_database {
    my ($self,$species) = @_;
    my $database = $species->db_symbolic_name;
    
    $self->log->debug("creating a new mysql GFF database: $database");
    
    my $drh = $self->drh;
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
    my ($self,$species) = @_;
    my $data_dir  = $self->mysql_data_dir;    
    my $target_db = $species->db_symbolic_name;
    $self->log->info("compressing mysql database");
    
    # Pack the database
    $self->system_call("myisampack $data_dir/$target_db/*.MYI",
		       'packing GFF mysql database');

    # Check the database
    $self->system_call("myisamchk -rq --sort-index --analyze $data_dir/$target_db/*.MYI",
		       'analyzing indexes');
}




sub check_database {
    my ($self,$species) = @_;
    $self->log->debug("checking status of new database");
    
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
    my $target_db = $species->db_symbolic_name;
    my $db        = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->log->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->log->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}


1;
