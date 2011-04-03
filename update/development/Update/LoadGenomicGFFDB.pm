package Update::LoadGenomicGFFDB;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';

# The symbolic name of this step
sub step { return 'load genomic feature gff databases'; }

sub run {
    my $self = shift;
    my $species = $self->species;
    my $release = $self->release;
    my $msg     = 'building genomic GFF database for';

    foreach my $species (@$species) {
		
	$self->logit->info("  begin: $msg $species");
	$self->target_db($species . '_' . $release);   
	$self->load_gffdb($species);
	$self->check_db($species);
	
	# Pack database
	$self->pack_database();
	
	my $target_db = $self->target_db;
	
	# $self->update_symlink({path => $self->mysql_data_dir,
	# 		       target  => $target_db,
	# 			   symlink => $species, # assumes config files are up-to-date as g_species -> g_species_release!
	# 			   });
	
	my $custom_gff  = $self->get_filename('genomic_gff2_archive',$species);
	$self->update_symlink({path    => join("/",
	 					       $self->ftp_root,
	 					       $self->local_ftp_path,
	 					       "genomes/$species/genome_feature_tables/GFF2"),
	 			       target  => "$gff",
	 			       symlink => 'current.gff2.gz',
	 			   });
	
	$self->logit->info("  end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}

sub load_gffdb {
    my ($self,$species) = @_;
    my $release = $self->release;
    
    $self->create_database($species);
 
    # Not discovering right now, just iterating over a list of species.
    my $gff    = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/$species.gff.gz");
    my $fasta  = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/$species.dna.fa.gz");
    
    # Need to do some small processing for some species.
    $self->logit->debug("processing $species GFF files");
   
    if ($species =~ /elegans/) {
	# process the GFF files
	my $cmd = "$Bin/../util/process_elegans_gff.pl $release $gff | gzip -cf > $gff.GBrowse.gz";
	system($cmd) && $self->logit->logdie("Something went wrong processing the GFF files: $!");	
    } else  { 
	
    }
    
    $ENV{TMP} = -d ('/usr/local/acedb/tmp') ? '/usr/local/acedb/tmp' : -d ('/tmp') ? '/tmp' : $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || 
	die 'Cannot find a suitable temp dir';
    
    my $db = $self->target_db;
    my $pass = $self->mysql_pass;
    my $load_cmd = "bp_bulk_load_gff.pl --user root --password $pass -c -d $db --fasta $fasta $gff 2> /dev/null";
    $self->logit->debug("loading database: $load_cmd");
    system($load_cmd);
    
    # Load the EST file for C. elegans. It powers seq/align and is created during the
    # CreateBlastDatabases step (somewhat incongruously)
    if ($species =~ /elegans/) {
        my $custom_filename  = $self->get_filename('est_archive',$species);
        my $est =join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/sequences/dna/$custom_filename");
        system("gunzip $est.gz");
	my $user = $self->mysql_user;
        my $pass = $self->mysql_pass;
        my $result = system "bp_load_gff.pl -d $db --user $user -password $pass --fasta $est </dev/null";
        system("gzip $est");
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

sub create_database {
    my ($self,$species) = @_;
    $self->logit->debug("creating a new mysql GFF database");
    
    my $database = $self->target_db;
    my $user = $self->mysql_user;
    my $pass = $self->mysql_pass;
    
	#  system "mysql -u root -pkentwashere -e 'drop database $database'"  or $self->logit->warn("couldn't drop database: $!");

    system "mysql -u root -p$pass -e 'create database $database'" or $self->logit->warn("couldn't create database: $!");
    system "mysql -u root -p$pass -e 'grant all privileges on $database.* to $user\@localhost'";
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
