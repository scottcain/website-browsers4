package Update::LoadGFFPatches;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';

# The symbolic name of this step
sub step { return 'load gff patches'; }

sub run {
    my $self = shift;
    my $release = $self->release;
    my $species = $self->species;
    my $msg     = 'loading gff patches for';
    foreach my $species (@$species) {
	next unless $species =~ /elegans/;  # only for elegans at this point
	$self->logit->info("  begin: $msg $species");
	$self->target_db($species . "_$release");   
	
	# Assume that each feature has its own dump script and requires acedb
	my $features = { 
	    motifs => {
		filename   => 'protein_motifs_gff2_archive',
		dump_cmd   => 'map_translated_features_to_genome.pl --filter',
	    },
	    intervals => {
		filename => 'genetic_intervals_gff2_archive',
		dump_cmd => 'interpolate_gmap2pmap.pl',
	    },
	};
	foreach my $feature (keys %$features) {
	    my $filename = $features->{$feature}->{filename};
	    my $cmd      = $features->{$feature}->{dump_cmd};
	    $self->load_feature($species,$filename,$cmd,$feature);
	}
	
	$self->logit->info("  end: $msg $species");
	my $fh = $self->master_log;
	print $fh $self->step . " $msg $species complete...\n";
    }
}

sub load_feature {
    my ($self,$species,$filename,$cmd,$feature) = @_;
    
    $ENV{TMP} = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : 
	die 'Cannot find a suitable temp dir';
    
    my $custom_gff   = $self->get_filename($filename,$species);
    
    # This is the gff archive that will be loaded
    my $gff_archive = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/annotations/gff_patches/$custom_gff");
    
    $self->logit->debug("dumping $feature...");
    
    my $acedb = $self->acedb_root . '/elegans_' . $self->release;
    my $cmd = "$Bin/../util/$cmd --acedb $acedb | gzip -cf 1> $gff_archive.gz 2> /dev/null";
    $self->logit->debug("dumping features via cmd $cmd");
    system($cmd);
    
    my $db = $self->target_db;
    my $load_cmd = "bp_load_gff.pl --dsn $db --user root --password kentwashere $gff_archive.gz 2> /dev/null";
    $self->logit->debug("loading database: $load_cmd");
    system($load_cmd);
}
    


1;
