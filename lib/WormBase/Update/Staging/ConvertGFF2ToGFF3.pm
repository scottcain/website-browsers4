package WormBase::Update::Staging::ConvertGFF2ToGFF3;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
use DBI;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'convert GFF2 annotations to GFF3',
    );


sub run {
    my $self = shift;

    # get a list of (symbolic g_species) names
    my ($species) = $self->wormbase_managed_species;
    my $release = $self->release;
    foreach my $name (@$species) {
	my $species   = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	my $gff2_file = $species->gff_file;       # this includes the full path.

	next unless ($species->gff_version == 2);
	$self->log->debug("creating GFF3 file for $name");
	
	my $symbolic_name = $species->symbolic_name;
	my $release_dir   = $species->release_dir;
	my $gff3_file     = join("/",$release_dir,"$symbolic_name.$release.annotations.gff3");       

	# Unzip the GFF2 file.
	$self->system_call("gunzip $gff2_file",
			  "gunzip $gff2_file");
	my $unzipped = $gff2_file;
	$unzipped    =~ s/\.gz//;
	
	# Helper script will dump to $gff3_file and create temp directory called $gff3_file-conversion-files
	my $cmd = $self->bin_path . "/../helpers/wormbase_gff2togff3.pl -species $symbolic_name -gff $unzipped -output $gff3_file";
	$self->system_call($cmd,$cmd);

	# Rezip
	system("gzip $unzipped");
	
	# Sort the file
#	my $sort = "gunzip -c $gff3_path/$gff3.temp.gz | sort -k9,9 - | gzip -c > $gff3_path/$gff3.gz";
	my $sort = "sort -k9,9 $gff3_file | gzip -c > $gff3_file.gz";
	$self->system_call($sort,$sort);

	# Clean up
	$self->system_call("rm -rf ${gff3_file}-conversion-files","rm -rf ${gff3_file}-conversion-files");
	$self->system_call("rm -f $gff3_file","rm -f $gff3_file");
	
	$self->log->info("gff2->gff3 conversion: done for $symbolic_name");
    }
}


1;
