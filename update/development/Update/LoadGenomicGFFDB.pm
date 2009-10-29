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
    
    # next if ($species =~ /elegans/);  ## unless
			
	## GFF3 set   	
	# 	next if ($species =~ /malayi/);
	# 	next if ($species =~ /hapla/);
	# 	next if ($species =~ /incognita/);
	
	# ce
	#	next if ($species =~ /elegans/);
	
	## GFF3 set   	
	#	next unless ($species =~ /malayi/);
	#	next unless ($species =~ /hapla/);
	#	next unless ($species =~ /incognita/);
	
	## ce
	next unless ($species =~ /elegans/);

	#	next unless $species =~ /elegans/ || $species =~ /remanei/ || $species =~ /briggsae/;
	#	next unless $species =~ /briggsae/; # WS200: success
	#	next unless $species =~ /elegans/;  # WS200: success
	#	next unless $species =~ /remanei/;  # WS200: success
	#	next unless $species =~ /japonica/;  # WS200: success
	#	next unless $species =~ /brenneri/;  # WS200: success
	#	next unless $species =~ /pacificus/;  # WS200: success
	#	next unless $species =~ /malayi/;  # WS200: success

	$self->logit->info("  begin: $msg $species");
	$self->target_db($species . '_' . $release);   
	$self->load_gffdb($species);
	$self->check_db($species);
	my $target_db = $self->target_db;
	
	# $self->update_symlink({path => $self->mysql_data_dir,
	# 		       target  => $target_db,
	# 			   symlink => $species, # assumes config files are up-to-date as g_species -> g_species_release!
	# 			   });
	
	my $custom_gff  = $self->get_filename('genomic_gff2_archive',$species);
	# $self->update_symlink({path    => join("/",
	# 					       $self->ftp_root,
	# 					       $self->local_ftp_path,
	# 					       "genomes/$species/genome_feature_tables/GFF2"),
	# 			       target  => "$custom_gff.gz",
	# 			       symlink => 'current.gff2.gz',
	# 			   });
	
	$self->logit->info("  end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}


sub load_gffdb_new {

    my ($self,$species) = @_;
    
    $self->create_database($species);
    
    my $gff_filename   = $self->get_filename('genomic_gff2_archive',$species);    # Filename of the GFF2 archive
    my $fasta_filename = $self->get_filename('genomic_fasta_archive',$species);   # Filename of the genomic fasta archive
    
    # This is the gff archive that will be loaded
    my $gff_archive_dir = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/genome_feature_tables/GFF2");
    my $gff_archive = "$gff_archive_dir/$gff_filename";
    
    # Fetch the fasta file
    my $fasta_archive = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna/$fasta_filename");
    $self->mirror_genomic_sequence($species);
    
    # Fetch the GFF
    unless (-e "$gff_archive.gz") {
	$self->mirror_gff_tables($species);
    }
    
    $self->logit->debug("processing $species GFF files");
    
    my @gff_files = "$gff_archive.gz";
    #my @gff_files = glob($self->mirror_dir . "/*.gff*");
    # Check if we have supplementary gff files
    if ($species =~ /elegans/) {      
    
	my $release = $self->release;
	my $ftp_remote_dir     = $self->remote_ftp_path . "/$release/genomes/$species/genome_feature_tables/SUPPLEMENTARY_GFF";
	my $local_mirror_dir = join("/",$self->mirror_dir);
	$self->mirror_directory($ftp_remote_dir,$local_mirror_dir);
	push @gff_files,glob($self->mirror_dir . "/SUPPLEMENTARY_GFF/*.gff");
	push @gff_files,glob($self->mirror_dir . "/SUPPLEMENTARY_GFF/*.gff*");
		
	# process the GFF files
	#my $acedb = $self->acedb_root . '/wormbase_' . $self->release;
	my $release  = $self->release;
	my $files = join(' ',@gff_files);
	my $cmd = "$Bin/../util/process_elegans_gff.pl $release $files | gzip -cf > $gff_archive.new.gz";
	
	my $cmd = "$Bin/../util/process_elegans_gff.pl $release $files | gzip -cf > $gff_archive.new.gz";
	
	system($cmd) && $self->logit->logdie("Something went wrong processing the GFF files: $!");
	
	# Remove the original file and replace it with the new one. Yuck.
	chdir($gff_archive_dir);
	system("rm -rf $gff_archive.gz");
	system("mv $gff_archive.new.gz $gff_archive.gz");
	
    } elsif ($species =~ /briggsae/) {
	
	# process the GFF files
	my $release = $self->release;
	my $files = join(' ',@gff_files);
	my $mirror_dir = $self->mirror_dir;
	my $cmd = "$Bin/../util/process_briggsae_gff.pl $release $gff_archive.gz | gzip -cf > $gff_archive.new.gz";
	system($cmd) && $self->logit->logdie("Something went wrong processing the GFF files: $!");
	
	# Remove the original file and replace it with the new one. Yuck.
	chdir($gff_archive_dir);
	system("rm -rf $gff_archive.gz");
	system("mv $gff_archive.new.gz $gff_archive.gz");
	
    } else  { 
    
    }

	# elsif ($species =~ /remanei/) {	    
	#	# Hack!  C. remanei files are not named consistently.
	#	my $cmd = "cp " . $self->mirror_dir . "/remanei.gff.gz  $gff_archive.gz";
	#	system($cmd);	
	#    }
    
    $ENV{TMP} = -d ('/usr/local/acedb/tmp') ? '/usr/local/acedb/tmp' : -d ('/tmp') ? '/tmp' : $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || 
	die 'Cannot find a suitable temp dir';
    
    system("gunzip $fasta_archive.gz");
    my $db = $self->target_db;
	#    my $load_cmd = "bp_bulk_load_gff.pl --user root --password kentwashere -c -d $db --fasta $fasta_archive $gff_archive.gz 2> /dev/null";
	my $pass = '3l3g@nz'; # 3l3g\@nz
    my $load_cmd = "bp_bulk_load_gff.pl --user root --password $pass -c -d $db --fasta $fasta_archive $gff_archive.gz 2> /dev/null";
    $self->logit->debug("loading database: $load_cmd");
    system($load_cmd);
    system("gzip -f $fasta_archive");
    
    # Load the EST file for C. elegans. It powers seq/align and is created during the
    # CreateBlastDatabases step (somewhat incongruously)
    if ($species =~ /elegans/) {
        my $custom_filename  = $self->get_filename('est_archive',$species);
        my $est =join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/sequences/dna/$custom_filename");
        system("gunzip $est.gz");
        my $pass = '3l3g@nz'; ## l3g\@nz
        my $result = system "bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null";
        system("gzip $est");
    }
}

sub load_gffdb {
    my ($self,$species) = @_;
    
    $self->create_database($species);
    
    my $gff_filename   = $self->get_filename('genomic_gff2_archive',$species);    # Filename of the GFF2 archive
    my $fasta_filename = $self->get_filename('genomic_fasta_archive',$species);   # Filename of the genomic fasta archive
    
    # This is the gff archive that will be loaded
    my $gff_archive_dir = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/genome_feature_tables/GFF2");
    my $gff_archive = "$gff_archive_dir/$gff_filename";
    
    # Fetch the fasta file
    my $fasta_archive = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna/$fasta_filename");
    $self->mirror_genomic_sequence($species);
    
    # Fetch the GFF
    unless (-e "$gff_archive.gz") {
	$self->mirror_gff_tables($species);
    }
    
    $self->logit->debug("processing $species GFF files");
    
    my @gff_files = "$gff_archive.gz";
    #my @gff_files = glob($self->mirror_dir . "/*.gff*");
    # Check if we have supplementary gff files
    if ($species =~ /elegans/) {      
	my $release = $self->release;
	my $ftp_remote_dir     = $self->remote_ftp_path . "/$release/genomes/$species/genome_feature_tables/SUPPLEMENTARY_GFF";
	my $local_mirror_dir = join("/",$self->mirror_dir);
	$self->mirror_directory($ftp_remote_dir,$local_mirror_dir);
	push @gff_files,glob($self->mirror_dir . "/SUPPLEMENTARY_GFF/*.gff");
	push @gff_files,glob($self->mirror_dir . "/SUPPLEMENTARY_GFF/*.gff*");
		
	# process the GFF files
	#my $acedb = $self->acedb_root . '/wormbase_' . $self->release;
	my $release  = $self->release;
	my $files = join(' ',@gff_files);
	my $cmd = "$Bin/../util/process_elegans_gff.pl $release $files | gzip -cf > $gff_archive.new.gz";
	system($cmd) && $self->logit->logdie("Something went wrong processing the GFF files: $!");
	
	# Remove the original file and replace it with the new one. Yuck.
	chdir($gff_archive_dir);
	system("rm -rf $gff_archive.gz");
	system("mv $gff_archive.new.gz $gff_archive.gz");
	
    } elsif ($species =~ /briggsae/) {
	# process the GFF files
	my $release = $self->release;
	my $files = join(' ',@gff_files);
	my $mirror_dir = $self->mirror_dir;
	my $cmd = "$Bin/../util/process_briggsae_gff.pl $release $gff_archive.gz | gzip -cf > $gff_archive.new.gz";
	system($cmd) && $self->logit->logdie("Something went wrong processing the GFF files: $!");
	
	# Remove the original file and replace it with the new one. Yuck.
	chdir($gff_archive_dir);
	system("rm -rf $gff_archive.gz");
	system("mv $gff_archive.new.gz $gff_archive.gz");
    } else  { 
    
    }

	# elsif ($species =~ /remanei/) {	    
	#	# Hack!  C. remanei files are not named consistently.
	#	my $cmd = "cp " . $self->mirror_dir . "/remanei.gff.gz  $gff_archive.gz";
	#	system($cmd);	
	#    }
    
    $ENV{TMP} = -d ('/usr/local/acedb/tmp') ? '/usr/local/acedb/tmp' : -d ('/tmp') ? '/tmp' : $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || 
	die 'Cannot find a suitable temp dir';
    
    system("gunzip $fasta_archive.gz");
    my $db = $self->target_db;
	#    my $load_cmd = "bp_bulk_load_gff.pl --user root --password kentwashere -c -d $db --fasta $fasta_archive $gff_archive.gz 2> /dev/null";
	my $pass = '3l3g@nz'; # 3l3g\@nz
    my $load_cmd = "bp_bulk_load_gff.pl --user root --password $pass -c -d $db --fasta $fasta_archive $gff_archive.gz 2> /dev/null";
    $self->logit->debug("loading database: $load_cmd");
    system($load_cmd);
    system("gzip -f $fasta_archive");
    
    # Load the EST file for C. elegans. It powers seq/align and is created during the
    # CreateBlastDatabases step (somewhat incongruously)
    if ($species =~ /elegans/) {
        my $custom_filename  = $self->get_filename('est_archive',$species);
        my $est =join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/sequences/dna/$custom_filename");
        system("gunzip $est.gz");
        my $pass = '3l3g@nz'; ## l3g\@nz
        my $result = system "bp_load_gff.pl -d $db --user root -password $pass --fasta $est </dev/null";
        system("gzip $est");
    }
}


sub create_database {
    my ($self,$species) = @_;
    $self->logit->debug("creating a new mysql GFF database");
    
    my $database = $self->target_db;
    my $user = 'root';
    my $pass = '3l3g@nz'; #3l3g\@nz
    
	#  system "mysql -u root -pkentwashere -e 'drop database $database'"  or $self->logit->warn("couldn't drop database: $!");

    system "mysql -u root -p$pass -e 'create database $database'" or $self->logit->warn("couldn't create database: $!");
    system "mysql -u root -p$pass -e 'grant all privileges on $database.* to $user\@localhost'";
}



sub check_database {
    my ($self,$species) = @_;
    $self->logit->debug("checking status of new database");
    
    my $user = 'root';
    my $pass = '3l3g@nz';  ## 3l3g\@nz
    
    my $target_db = $self->target_db;
    my $db     = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->logit->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->logit->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}


1;
