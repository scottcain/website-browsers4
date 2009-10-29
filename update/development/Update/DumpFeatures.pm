package Update::DumpFeatures;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';

# The symbolic name of this step
sub step { return 'dump features'; }

sub run {
    my $self = shift;
    my $release = $self->release;
    my $species = $self->species;
    my $msg     = 'dumping features for';
    foreach my $species (@$species) {
	next unless $species =~ /elegans/;  # only for elegans at this point
	$self->logit->info("  begin: $msg $species");
	$self->target_db($species . "_$release");   

    # Assume that each feature has its own dump script and requires acedb
    my $features = {
#		    gene_names => {
#				filename   => 'protein_motifs_gff2_archive',
#				dump_cmd   => 'map_translated_features_to_genome.pl --filter',
#			       },
		    functional_descriptions => { dump_cmd => 'dump_functional_descriptions.pl --database', },
		    swissprot               => { dump_cmd => 'dump_swissprot.pl -acedb', },
		    gene_ontology           => { dump_cmd => 'dump_gene_ontology.pl',    },
		    genetic_interactions    => { dump_cmd => 'dump_genetic_interactions.pl', },
		    laboratories            => { dump_cmd => 'dump_laboratories.pl',     },
		    brief_ids               => { dump_cmd => 'dump_brief_ids.pl --database', },
		   };
      foreach my $feature (keys %$features) {
	my $filename = $features->{$feature}->{filename};
	my $cmd      = $features->{$feature}->{dump_cmd};
	$self->load_feature($species,$feature,$cmd);
      }
    
    $self->logit->info("  end: $msg $species");
    my $fh = $self->master_log;
    print $fh $self->step . " $msg $species complete...\n";
  }
}

sub load_feature {
  my ($self,$species,$feature,$cmd) = @_;
  
  $ENV{TMP} = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : 
    die 'Cannot find a suitable temp dir';
  
  my $release = $self->release;
  my $custom   = sprintf("%s.%s.%s.txt",$species,$release,$feature);
  
  # Output target
  my $parent = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/annotations/$feature");
  $self->_make_dir($parent);
  my $archive = "$parent/$custom";
  
  $self->logit->debug("dumping $feature...");
  
  my $acedb = $self->acedb_root . '/elegans_' . $self->release;
  my $cmd = "$Bin/../util/$cmd $acedb | gzip -cf 1> $archive.gz 2> /dev/null";
  $self->logit->debug("dumping features via cmd $cmd");
  system($cmd);

  $self->update_symlink({path    => $parent,
			 target  => "$custom.gz",
			 symlink => 'current.gz',
			});
  return;
}
    


1;
