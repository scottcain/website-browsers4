package Update::CreateBlastDatabases;

use local::lib '/usr/local/wormbase/website-classic/extlib';
use strict;
use Ace;
use base 'Update';
use File::Slurp qw(slurp);


# The symbolic name of this step
sub step { return 'create blast databases'; }

sub run {
  my $self = shift;
  
  my $msg = 'creating blast databases for';
  
  ## for m_incognita /h_bacteriophora for WS205
#  my @species;
#  push @species, 'm_incognita';
#  my $species = \@species;
  
  ### end for m_incognita for WS205
  
  my $species = $self->species;
  
  # Stash some variables so I don't have to keep regenerating them over and over.  
  $self->target_root($self->get_blastdb_dir);
  
  foreach my $species (@$species) {
#  next unless ($species =~ /incognita/);
#   next unless ($species =~ /bacteriophora/);
#	next unless ($species =~ /elegans/); ## unless
#	next if ($species =~ /brenneri/);
#	next if ($species =~ /malayi/);
#	next if ($species =~ /japonica/);
#	next if ($species =~ /briggsae/);
#	next if ($species =~ /remanei/);
	next if ($species =~ /elegans/);
      #$self->_make_dir($self->mirror_dir);
      $self->logit->info("  begin: $msg $species");
      
      $self->species_root($self->target_root . "/$species");
      $self->_make_dir($self->species_root);
      
      $self->create_nucleotide_dbs($species);
      $self->create_protein_dbs($species);  
      $self->create_est_db($species);
      $self->create_gene_db($species);
      $self->logit->info("  end: $msg $species");
      my $fh = $self->master_log;
      print $fh $self->step . " $msg $species complete...\n";
  }
}


sub create_nucleotide_dbs {
    my ($self,$species) = @_;
    $self->logit->info("  generating $species genomic nucleotide database");
    my $release = $self->release;
    
    # mirror if necessary
    $self->mirror_genomic_sequence($species);     
    $self->_remove_dir($self->mirror_dir);
    
    # Unpack the genomic sequence
    my $custom_filename = $self->get_filename('genomic_fasta_archive',$species);  # Genomic FASTA filename on the FTP site
    my $generic_filename = $self->get_filename('nucleotide_blast');               # Name of genomic blast file
    
    my $target_file = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna/$custom_filename.gz");
    chdir($self->species_root) or $self->logit->warn("couldnt chdir $self->species_root");
    system("gunzip -c $target_file > $generic_filename");      
    
    $self->make_blastdb($species,'nucleotide');
    $self->logit->info("  generating $species genomic nucleotide database: complete");
}


sub create_protein_dbs {
    my ($self,$species) = @_;
    
    $self->logit->info("  generating $species protein blast database");
    my $release = $self->release;
    
    # Get the generic filename for nucleotide blast databases
    my $generic_filename = $self->get_filename('protein_blast');
    
    if (1) {
#	$species =~ /b_malayi/         missing from sanger in WS194
#	$species =~ /c_brenneri/       missing from sanger in WS194
#	$species =~ /c_briggsae/
#	|| $species =~ /c_elegans/     broken in WS194
#	|| $species =~ /c_japonica/    missing from sanger in WS194
#	|| $species =~ /c_remanei/     broken in WS194
#	|| $species =~ /h_bacteriophora/  missing from sanger in WS194
#	|| $species =~ /p_pacificus/
#	) {
	my $numeric = $self->release_id;
	
	# Fetch the wormpep tarball
	my $remote_filename = sprintf($self->config->{species_info}->{$species}->{remote_protein_filename},$release);
	my $file_root = $remote_filename;
	$file_root =~ s/\.tar\.gz//;
	$file_root =~ s/\.gz//;
	
#	# Ugh. Exasperating inconsistency.
#	my $unpack = $remote_filename =~ /tar\.gz/ ? 'tar xzf' : 'gunzip';

	my $unpack = "gunzip";
	my $ftp_remote_dir   = join("/",$self->remote_ftp_path,"$release/genomes/$species/sequences/protein");
	my $local_mirror_dir = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/protein");
	
	$self->mirror_file($ftp_remote_dir,$remote_filename,$local_mirror_dir);
	
	$self->update_symlink({path    => $local_mirror_dir,			   
			       target  => $remote_filename,
			       symlink => 'current.gz',
			   });
	
#	# Unpack the tarball package
#	chdir($self->species_root);
#	my $cmd = <<END;
#cp $local_mirror_dir/$remote_filename .
#$unpack $remote_filename
## Either / or - another inconsistency
#mv $file_root/$file_root $generic_filename
#mv $file_root $generic_filename
#rm -rf $file_root$numeric $remote_filename
#END
#    ;

	# Unpack the tarball package
	chdir($self->species_root);
	my $cmd = <<END;
$unpack -c $local_mirror_dir/$remote_filename > $generic_filename
END
    ;

	system($cmd);	
	$self->make_blastdb($species,'protein');
    }
#  } else {
#    
#    # Need to add protein DBs
#    # for brugia, japonica, brenneri once gene sets are available.    
#      if ($species =~ /malayi/) {
#	  $self->unpack_archived_sequence({species => $species,
#					   target_file => $self->species_root . "/$generic_filename",
#					   type => 'protein',
#				       });
#	  my $this_release = $self->config->{species_info}->{$species}->{current_release};       
#	  $self->make_blastdb($species,'nucleotide',$this_release);   
#      }    
#  }
  $self->logit->info("generating $species protein blast database: complete");
}

# Currently only for elegans
sub create_est_db {
    my ($self,$species) = @_;    
    return unless $species =~ /elegans/;
    
    $self->logit->info("  generating $species est blast database");
    
    my $release = $self->release;
    my $acedb   = "/usr/local/wormbase/acedb_$release"; ## $self->acedb_root . "/elegans
    
    my $custom_filename  = $self->get_filename('est_archive',$species);
    my $generic_filename = $self->get_filename('ests_blast');
    
    # Dump the file to the FTP site
    my $output = join("/",$self->ftp_root,$self->local_ftp_path,"/genomes/$species/sequences/dna/$custom_filename");
    
    my $bin_root = $self->bin_root;
    my $script = "$bin_root/../util/dump_ests.pl";
    system("$script > $output");
    
    # Copy to the blast_dir
    my $root = $self->target_root;
    system("cp $output $root/$species/$generic_filename");
    
    # And compress the archived file
    system("gzip -f $output");
    
    $self->make_blastdb($species,'ests');
    $self->logit->info("  generating $species est blast database: complete");
}


# Create a gene database - currently only for C. elegans
sub create_gene_db {
    my ($self,$species) = @_;    
    return unless ($species =~ /elegans/ || $species =~ /briggsae/);
    $self->logit->info("  generating $species gene blast database");
    
    my $release = $self->release;
    my $acedb = $self->acedb_root . "/elegans_$release";
    my $generic_filename = $self->get_filename('genes_blast');
    
    my $output = $self->target_root . "/$species/$generic_filename";
    
    my $bin_root = $self->bin_root;
    my $script = "$bin_root/../util/dump_nucleotide.pl";
    system("$script $acedb $species > $output");
    
    $self->make_blastdb($species,'genes');
    $self->logit->info("  generating $species gene blast database: complete");
}


sub make_blastdb {
  my ($self,$species,$type,$this_release) = @_;
  $self->logit->debug("formatting $type blast database for $species");
  my $release = $self->release;
  
  # Build the blast title
  my $title = sprintf("%s %s release [%s]",$species,$type,$release);
  $title .= " assembly: $this_release" if $this_release;  # For rarely updated Tier II/IIIs.
  
  my $input = $self->get_filename($type . '_blast');
  
  # Insert the title and input file
  my $cmd = sprintf($self->config->{formatdb}->{$type},
		    $title,$input);
  
  my $formatdb = $self->blastdb_format_script;
  my $full_cmd = "$formatdb $cmd";
  
  my $blastdb_dir = $self->get_blastdb_dir . "/$species";  
  chdir($blastdb_dir); 
  system("$full_cmd") && $self->logit->logdie("something went wrong formatting the $type database for $species: $!");
  $self->logit->debug("formatting $type blast database for $species: complete");
}

1;
