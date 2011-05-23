package WormBase::Update::Staging::DumpAnnotations;

use lib "/usr/local/wormbase/website/tharris/extlib";
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'dump_annotations',
    );

sub run {
    my $self    = shift;
    my $release = $self->release;
    my $acedb_path = join("/",$self->acedb_root,"wormbase_$release");

    # Get a list of dump scripts.
    # Dunmp scripts should abide by the following conventions.
    # 1. Be located in update/staging/dump_scripts/
    # 2. Be name dump_*
    # 3. Accept --acedb_path as a generic param even if not required.
    # 4.
    
    my $dump_path = $self->bin_path . '/annotation_dump_scripts';
    my @dump_scripts = glob("$dump_path/dump*");
    foreach my $script (@dump_scripts) {
	$self->log->info("running annotation dump script $script");
	
	my @
	    $self->system_call("$script --acedb_path $acedb_path");

	$self->target_db($species . "_$release");   
	
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
