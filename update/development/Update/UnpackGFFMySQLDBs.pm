package Update::UnpackGFFMySQLDBs;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'unpacking gff mysql dbs from Sanger'; }

sub run {

	my $self = shift;
	my $release = $self->release;
	my $support_db_dir = $self->support_dbs;
	
	### intialize variables

	my $datadir = $support_db_dir . "/web_data";
	my $md5_in_dir = "md5_in";
	my $md5_ref_dir = "md5_ref";
	my $mysql_tgz_dir = "mysql_tgzs";
	## my $mysql_data_dir = "/usr/local/mysql/data";
	my $mysql_data_dir = $support_db_dir . "/mysql_test";
	
	my %species_db2sanger_db_name = (
		b_malayi => brugia,
		can => can,
		c_brenneri => brenneri,
		c_briggsae => briggsae,
		c_elegans => elegans,
		c_japonica => japonica,
		c_remanei => remanei,
		h_contortus => hcontortus,
		m_hapla => hapla,
		m_incognita => mincognita,
		p_pacificus => pristionchus,
	);
	
	## start
	
	# get md5 files from sanger and place in the md5_in directory
	
	system ("rm $datadir/$md5_in_dir/*");
	system ("mv $datadir/$mysql_tgz_dir/*md5 $datadir/$md5_in_dir" );
	
	## loop through md5 files to assess update status of corresponding mysql tar files
	
	my $md5_in_file_list = `ls $datadir/$md5_in_dir`;
	my @md5_in_files = split /\n/, $md5_in_file_list;
	my $md5_ref_file_list = `ls $datadir/$md5_ref_dir`;
	my @get_corresponding_files;
	
	### foreach md5 file in md5_in directory
		foreach my $md5_in_file (@md5_in_files) {	
		## is there a corresponding file in the md5_ref directory
			# no: 
			if(!($md5_ref_file_list =~ m/$md5_in_file/)) {
			
				print "file_not_present\n";	
				# move file to md5_ref
				system ("mv $datadir/$md5_in_dir/$md5_in_file $datadir/$md5_ref_dir");
				# list to pull associated mysql file from sanger and uncompress in appropriate directory			
				my ($species, $disc) = split /\./,$md5_in_file;
				push @get_corresponding_files, $species;
			}
			# yes
			else {
				## get strings for the two versions and compare
				my $in_string = `more $datadir/$md5_in_dir/$md5_in_file`;
				my $ref_string = `more $datadir/$md5_ref_dir/$md5_in_file`;
				
				## is the corresponding file in the md5_ref directory identical
				#yes:
				if ($in_string eq $ref_string) {
					# next
					next;
				}
				#no: 	
				else {
					# replace file in the md5_ref with file in md5_in
					system ("mv $datadir/$md5_in_dir/$md5_in_file $datadir/$md5_ref_dir");
					# pull associated mysql file from sanger and uncompress in appropriate directory
					my ($species, $disc) = split /\./,$md5_in_file;
					push @get_corresponding_files, $species;
				}									
			}
		}	### end foreach md5 file in md5_in directory
						
											
	print "@get_corresponding_files\n";					
	
	
	foreach my $species_name (@get_corresponding_files) {
	
		print "processing file for $species_name\n";
		
		my $check_file = "$species_name\_check.chk";
	
		print "unzipping file for $species_name\n";
		my $unzip_command = "bunzip2 $datadir/$mysql_tgz_dir/$species_name.tar.bz2";
		Update::system_call($unzip_command,$check_file);
	
		print "untarring file for $species_name\n";
		my $untar_command = "tar -C $mysql_data_dir -xvf $datadir/$mysql_tgz_dir/$species_name.tar";
		Update::system_call($untar_command,$check_file);
		
		print "removing tar file\n";
		Update::system_call("rm $datadir/$mysql_tgz_dir/$species_name.tar", $check_file);
		
		print "reming db for $species_name\n";
		my $stage_name = $species_name . "_" .$release;
		my $sanger_db_name = $species_db2sanger_db_name{$species_name};
		Update::system_call("mv $mysql_data_dir/$sanger_db_name  $mysql_data_dir/$stage_name", $check_file);
		
		print "Updating permissions for $species_name\n";
		Update::system_call("chmod 775 $mysql_data_dir/$stage_name",$check_file);
	}
}

1;
