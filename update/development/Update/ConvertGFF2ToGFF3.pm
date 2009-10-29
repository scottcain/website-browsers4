package Update::ConvertGFF2ToGFF3;

use base 'Update';
use FindBin qw/$Bin/;
use strict;

# The symbolic name of this step
sub step { return 'convert GFF2 to GFF3'; }

sub run {
    my $self = shift;
    
    my $species = $self->species;
    my $release = $self->release;    
    my $msg     = 'converting GFF2 to GFF3 for';
    foreach my $species (@$species) {
	next unless ($species =~ /elegans/ || $species =~ /briggsae/);
#	next unless $species =~ /elegans/;
	$self->logit->info("  begin: $msg $species");


	my $gff2   = $self->get_filename('genomic_gff2_archive',$species);
	my $gff2_path = join("/",
			     $self->ftp_root,
			     $self->local_ftp_path,
			     "genomes/$species/genome_feature_tables/GFF2");
	
	
	my $gff3   = $self->get_filename('genomic_gff3_archive',$species);
	my $gff3_path = join("/",
			     $self->ftp_root,
			     $self->local_ftp_path,
			     "genomes/$species/genome_feature_tables/GFF3");
	
#	my $cmd = "$Bin/../util/wormbasegff2togff3.pl $gff2_path/$gff2.gz | gzip -c > $gff3_path/$gff3.temp.gz";
	
	# This is the expanded wormbase_gff2togff3.pl that currently does not work.
	system("gunzip $gff2_path/$gff2.gz");
	my $cmd = "$Bin/../util/wormbase_gff2togff3.pl -species $species -gff $gff2_path/$gff2 -output $gff3_path/$gff3.temp";
	system($cmd);
	system("gzip $gff2_path/$gff2");
	
	# This is the old converter script
        # my $cmd = "$Bin/../util/wormbasegff2gff3.pl $gff2_path/$gff2.gz | gzip -c > $gff3_path/$gff3.temp.gz";
        # system($cmd);
	
	# The file also needs to be sorted.
	# sort -k9,9 file.gff3 > sorted_file.gff3 
#	my $sort = "gunzip -c $gff3_path/$gff3.temp.gz | sort -k9,9 - | gzip -c > $gff3_path/$gff3.gz";
	my $sort = "sort -k9,9 $gff3_path/$gff3.temp | gzip -c > $gff3_path/$gff3.gz";
	system($sort);
	system("rm -f $gff3_path/$gff3.temp");
	
	$self->update_symlink({path    => $gff3_path,
			       target  => "$gff3.gz",
			       symlink => 'current.gff3.gz',
			   });
	
	$self->logit->info("  end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";	
    }
}


1;
