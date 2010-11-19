package Update::MirrorAnnotations;

use strict;
use base 'Update';

# The symbolic name of this step
sub step { return 'mirror annotations from Sanger'; }

sub run {
    my $self = shift;
    
    my $msg = 'mirroring annotations from Sanger';
    my $species = $self->species;
    
    my $release         = $self->release;
    my $remote_ftp_path = $self->remote_ftp_path;    
    
    foreach my $species (@$species) {
	next unless $species =~ /elegans/;  # Currently only for elegans
	
	my $ftp_remote_dir = "$remote_ftp_path/$release/genomes/$species/annotation";
	
	my $local_dir = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/annotations");
	$self->mirror_directory($ftp_remote_dir,$local_dir);
	
	# Now move files as appropriate. Stupid.
	chdir($local_dir);
        system("rm -rf microarray/*");  # clean out cruft
	system("mv affy_oligo_mapping.gz microarray/.");
	system("mv agil_oligo_mapping.gz microarray/.");
	system("mv cDNA2orf.$release.gz gene_ids/.");
	system("mv confirmed_genes.$release.gz confirmed_genes/.");
	system("mv geneIDs.$release.gz gene_ids/.");
	system("mv gsc_oligo_mapping.gz microarray/.");
	system("mv knockout_consortium_alleles.$release.xml.bz2 alleles/.");
	system("mv pcr_product2gene.$release.gz pcr_products/.");
	system("rm -rf letter.*");
    }
    
    
    # Get the release letter
    my $target_dir  = $self->root . "/website-classic/html/release_notes";
    my $staging_dir = $self->root . "/website-classic-staging/html/release_notes";
    my $ftp_remote_path = "$remote_ftp_path/$release";
    $self->mirror_file($ftp_remote_path,"letter.$release",$target_dir);
    $self->mirror_file($ftp_remote_path,"letter.$release",$staging_dir);
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}

1;
