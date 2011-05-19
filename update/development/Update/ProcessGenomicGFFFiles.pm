package Update::ProcessGenomicGFFFiles;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';

# The symbolic name of this step
sub step { return 'process genomic feature gff files'; }

sub run {
    my $self = shift;
    my @species = ("c_briggsae"); ## , "c_elegans"
    my $release = $self->release;
    my $msg     = 'processing genomic GFF file for';
    
    foreach my $species (@species) {
    
	$self->logit->info("  begin: $msg $species");
	$self->process_gff_files($species);
	
	$self->logit->info("  end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}


sub process_gff_files{

    my ($self,$species) = @_;    
    my $gff_filename   = $self->get_filename('genomic_gff2_archive',$species);    # Filename of the GFF2 archive
    
    # This is the gff archive that will be loaded
    my $gff_archive_dir = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/genome_feature_tables/GFF2");
    my $gff_archive = "$gff_archive_dir/$gff_filename";
    
    
    # Fetch the GFF
    unless (-e "$gff_archive.gz") {
		$self->mirror_gff_tables($species);
    }
    
    $self->logit->debug("processing $species GFF files");
    
    my @gff_files = "$gff_archive.gz";
    my $release  = $self->release;	
    
	if ($species=~ /elegans/) {   #

		#my $local_mirror_dir = join("/",$self->mirror_dir);
		my $supplementary_dir = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/genome_feature_tables/SUPPLEMENTARY_GFF");
		push @gff_files, glob($supplementary_dir . "/*.gff");
		
		#push @gff_files,glob($self->mirror_dir . "/SUPPLEMENTARY_GFF/*.gff*");
			
		# process the GFF files

		my $files = join(' ',@gff_files);
		#print "$files/n";
		
		my $cmd = "$Bin/../util/process_elegans_gff.pl  $files | gzip -cf > $gff_archive.new.gz"; ## $release
		
		# print "$cmd\n";
		
		print "running $cmd\n\n";
		
		Update::system_call($cmd,"processing.chk") && $self->logit->logdie("Something went wrong processing the GFF files: $!");
		
		print "$cmd -- done\n\n";
		
		# Remove the original file and replace it with the new one. Yuck.
		chdir($gff_archive_dir);
		
		Update::system_call("rm -rf $gff_archive.gz","processing.chk");
		
		print "removing old gff.gz file -- done\n\n";
		
		Update::system_call("mv $gff_archive.new.gz $gff_archive.gz","processing.chk");
		
		print "file replaced\n\n";
	} 
	elsif ($species=~ /briggsae/) {
		
		# process the GFF files
		my $release = $self->release;
		my $files = join(' ',@gff_files);
		my $mirror_dir = $self->mirror_dir;
		
		my $cmd = "$Bin/../util/process_briggsae_gff.pl $gff_archive.gz | gzip -cf > $gff_archive.new.gz"; 
		
		print "running $cmd\n\n";
		
		Update::system_call($cmd,"processing.chk") && $self->logit->logdie("Something went wrong processing the GFF files: $!");
		
		print "$cmd -- done\n\n";
		
		# Remove the original file and replace it with the new one. Yuck.
		chdir($gff_archive_dir);
		Update::system_call("rm -rf $gff_archive.gz","processing.chk");
		print "removing old gff.gz file -- done\n\n";
		Update::system_call("mv $gff_archive.new.gz $gff_archive.gz","processing.chk");
		print "file replaced\n\n";
	}
	else  { 
    
    }
}




1;
