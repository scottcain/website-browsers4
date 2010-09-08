package Update::UnpackGFFMySQLDBs.pm

use strict;
use base 'Update';


sub step {return 'unpack gff mysql dbs'}

sub run {
	
	our $datadir = "/usr/local/wormbase/databases/web_data";
	our $md5_in_dir = "md5_in";
	our $md5_ref_dir = "md5_ref";
	our $mysql_tgz_dir = "mysql_tgzs";
	# our $mysql_data_dir = "/usr/local/mysql/data";
	# our $mysql_data_dir = "/usr/local/wormbase/databases/mysql_data_test";
	
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
	 
	### test array
	
	#my @mysql_files = qw/p_pacificus/;
	#print "@mysql_files\n";
	#@mysql_files
	
	foreach my $species_name (@get_corresponding_files) {
	
		print "processing file for $species_name\n";
	
	#	print "moving file for $species_name\n";
	#	my $move_command = "mv $datadir/$mysql_tgz_dir/$species_name.tar.bz2 $mysql_data_dir";
	#	system_call($move_command,$check_file);
		
		my $check_file = "$species_name\_check.txt";
	
		print "unzipping file for $species_name\n";
		my $unzip_command = "bunzip2 $datadir/$mysql_tgz_dir/$species_name.tar.bz2";
		system_call($unzip_command,$check_file);
	
	#	system_call("cd $mysql_data_dir",$check_file);
	
		print "untarring file for $species_name\n";
		my $untar_command = "tar -C $mysql_data_dir -xvf $datadir/$mysql_tgz_dir/$species_name.tar";
		system_call($untar_command,$check_file);
		
	#	print "moving data file\n";
	#	system_call("mkdir $mysql_data_dir/$species_name",$check_file);
	#	system_call("mv $datadir/$mysql_tgz_dir/$species_name/* /$species_name", $check_file);
		
		print "removing tar file\n";
		system_call("rm $datadir/$mysql_tgz_dir/$species_name.tar", $check_file);
		
	}

}

1;



