package Update::LoadGeneticGFFDB;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';

use constant DB_SUFFIX => '_gmap';

# The symbolic name of this step
sub step { return 'load genetic map gff databases'; }

sub run {
    my $self = shift;
    
    my $msg = 'creating genetic map gff databases for';
    my $release = $self->release;
    my $species = $self->species;
    foreach my $species (@$species) {
	next unless $species =~ /elegans/;  # only for elegans at this point
	$self->logit->info("  begin: $msg $species");
	$self->target_db($species . DB_SUFFIX . "_$release");   
	$self->load_gffdb($species);
	
	my $target_db = $self->target_db;
	$self->update_symlink({path    => $self->mysql_data_dir,
			       target  => $target_db,
			       symlink => $species . DB_SUFFIX,   # assumes config files are up-to-date as g_species -> g_species_release!
			   });
	
	$self->logit->info("   end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}

sub load_gffdb {
    my ($self,$species) = @_;
    
    $self->create_database();
    
    $ENV{TMP} = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : 
	die 'Cannot find a suitable temp dir';
    
    my $custom_gff   = $self->get_filename('genetic_map_gff2_archive',$species);
    
    # This is the gff archive that will be loaded
    my $gff_archive = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/genome_feature_tables/GFF2/$custom_gff");
    
    # Create the genetic map
    $self->logit->debug("dumping genetic map data in GFF for  $species GFF");
    
    my $acedb = $self->acedb_root . '/elegans_' . $self->release;
    my $cmd = "$Bin/../util/genetic_map/create_genetic_map.pl --acedb $acedb | gzip -cf > $gff_archive.gz";
    system($cmd) && $self->logit->logdie("Something went wrong generating the genetic map: $!");
    
    my $db = $self->target_db;
    my $load_cmd = "bp_fast_load_gff.pl --create --database $db --user root --password kentwashere $gff_archive.gz 2> /dev/null";
    $self->logit->debug("loading database: $load_cmd");
    system($load_cmd) && $self->logit->logdie("Something went wrong loading the genetic map: $!");
}



sub create_database {
    my $self = shift;
    $self->logit->debug("creating a new mysql GFF database");
    
    my $database = $self->target_db;
    my $user = 'root';
    my $pass = 'kentwashere';
    #  system "mysql -u root -pkentwashere -e 'drop database $database'"  or $self->logit->warn("couldn't drop database: $!");
    system "mysql -u root -pkentwashere -e 'create database $database'" or $self->logit->warn("couldn't create database: $!");
    system "mysql -u root -pkentwashere -e 'grant all privileges on $database.* to $user\@localhost'";
}


sub check_database {
    my ($self,$species) = @_;
    $self->logit->debug("checking status of new database");
    
    my $user = 'root';
    my $pass = 'kentwashere';
    
    my $target_db = $self->target_db;
    my $db     = DBI->connect('dbi:mysql:'.$target_db,$user,$pass) or $self->logit->logdie("can't DBI connect to database");
    my $table_list = $db->selectall_arrayref("show tables")
	or $self->logit->logdie("Can't get list of tables: ",$db->errstr);
    
    # optimize some tables
    $db->do("analyze table fattribute,fattribute_to_feature,fdata,fgroup,fmeta,ftype,fdna");
}

1;
