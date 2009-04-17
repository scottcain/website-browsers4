package Update;

use strict;
use Net::FTP::Recursive;
use Log::Log4perl;
use FindBin qw($Bin);
use IO::File;
our $AUTOLOAD;

my %config =  (
	       root => '/usr/local/wormbase',
	       
	       directories => {
			       support_dbs => "databases",
			       database_tarballs => 'mirror/database_tarballs',
			      },

	       # Where we will mirror files from Sanger
	       mirror_dir => '/tmp/temporary_update_dir',
	       
	       # acedb and mysql
	       acedb_root     => '/usr/local/acedb',
	       mysql_data_dir => '/usr/local/mysql/data',
	       
	       # FTP server access
	       wormbase_ftp_host   => 'brie4.cshl.org',
	       contact_email       => 'webmaster@wormbase.org',
	       remote_ftp_server   => 'ftp.sanger.ac.uk',
	       remote_ftp_path     => 'pub2/wormbase',
	       
	       # Local FTP server
	       ftp_root            => '/usr/local/ftp',	       
	       local_ftp_path      => 'pub/wormbase',

	       # Filenames on the FTP site
	       filenames => { generic => {
					  nucleotide_blast => 'genomic.fa',
					  protein_blast    => 'peptide.fa',
					  ests_blast       => 'ests.fa',
					  genes_blast      => 'genes.fa',
					  epcr             => 'epcr.fa',
					  oligos           => 'oligo.db',
					 },
			      custom => {
					 genomic_gff2_archive           => '%s.%s.gff',
					 genomic_gff3_archive           => '%s.%s.gff3',
					 genomic_fasta_archive          => '%s.%s.dna.fa',
					 genetic_map_gff2_archive       => '%s.%s.genetic_map.gff',
					 physical_map_gff2_archive      => '%s.%s.physical_map.gff',
					 protein_motifs_gff2_archive    => '%s.%s.protein_motifs.gff',
					 genetic_intervals_gff2_archive => '%s.%s.genetic_intervals.gff',
					 est_archive                    => '%s.%s.est.fa',
					},
			    },

	       # Miscellaneous files at Sanger
	       clustal_file  => 'wormpep_clw.sql',
	       
	       # BLAST DB config
	       blastdb_format_script => '/usr/local/blast/bin/formatdb',
	       formatdb    => {
			       nucleotide => qq{-p F -t '%s' -i %s},
			       ests       => qq{-p F -t '%s' -i %s},
			       protein    => qq{-p T -t '%s' -i %s},
			       genes      => qq{-p F -t '%s' -i %s},
			      },   
    
	       # Some species aren't part and parcel of the build yet.
	       # These may have non-standard file names/paths remotely
	       # or locally.
	       species_info => {
		   # WS196 - 10/31
		   b_malayi   => {
#		       current_release => 'Assembly Bma1',
#		       local_dna_filename => 'sequences/dna/bma1.assembly.fa.gz',
#		       local_protein_filename  => 'sequences/protein/bma1.pep.fa.gz',
#		       remote_dna_filename     => 'brugia.dna',
		       remote_protein_filename => 'brugpep.%s.fa.gz',
		   },
		   # WS196 - 10/31
		   c_brenneri => { 
#		       current_release => '2007.01 Draft Assembly',  # BLAST DB titles, etc.
#		       local_dna_filename => 'assembly/2007.01-draft_assembly/output/fasta/*.fa.gz',
#		       remote_dna_filename     => 'brenneri.dna',
		       remote_protein_filename => 'brepep.%s.fa.gz',
		   },
		   c_briggsae => {
		       remote_protein_filename => 'brigpep.%s.fa.gz',
		   },
		   c_elegans  => {
		       remote_protein_filename => 'wormpep.%s.fa.gz',
		   },
		   # WS195
		   c_japonica  => {
#		       current_release => 'Draft Assembly 3.0.2',
#		       local_dna_filename => 'assembly/draft_assembly_3.0.2/assembly/fasta/supercontigs.fa.gz',
#		       remote_dna_filename => 'supercontigs.agp',
		       remote_protein_filename => 'jappep.%s.fa.gz',
		   },						 
		   c_remanei => {
#		       remote_dna_filename => 'remanei.dna.gz',	
		       remote_protein_filename => 'remapep.%s.fa.gz',
		   },
		   h_bacteriophora => {
		       remote_protein_filename => 'hetpep.%s.fa.gz',
		   },
		   # WS194
		   p_pacificus => {
		       remote_gff2_filename    => 'pristionchus.gff.gz',
#		       remote_dna_filename     => 'pacificus.dna.gz',
		       remote_protein_filename => 'ppapep.%s.fa.gz',
		   },
	       },
	       fatonib => '/usr/local/blat/bin/faToNib',
	       
	       mysql_user => 'root',
	       mysql_pass => 'kentwashere',

	      );

sub new {
  my ($self,$params) = @_;
  my $this = bless $params,$self;
  $this->{config} = \%config;
  
  my $release = $this->release;

  my $step = $this->step();

  my $log_config = qq(
log4perl.logger.rootLogger  = INFO,LOGFILE,Screen

# Global spacing
log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=$Bin/../logs/$release/$step.log
log4perl.appender.LOGFILE.mode=append
log4perl.appender.LOGFILE.layout = Log::Log4perl::Layout::PatternLayout
#log4perl.appender.LOGFILE.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
log4perl.appender.LOGFILE.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#log4perl.appender.LOGFILE.layout.ConversionPattern=[%d %p]%K %n


log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr  = 0
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
#log4perl.appender.Screen.layout.ConversionPattern=[%d %r]%K%F %L %c − %m%n
log4perl.appender.Screen.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#log4perl.appender.Screen.layout.ConversionPattern=[%d %p]%K %n
);
  
  Log::Log4perl::Layout::PatternLayout::add_global_cspec('K',
							 sub {
     my ($layout, $message, $category, $priority, $caller_level) = @_;

     # FATAL, ERROR, WARN, INFO, DEBUG, TRACE
     return "   --> "    if $priority eq 'DEBUG';
     return " " if $priority eq 'INFO';
     return "  ! "   if $priority eq 'WARN';  # potential errors
     return " !! "   if $priority eq 'ERROR'; # errors
     return "!!! " if $priority eq 'FATAL';  # fatal errors
     return " ";
   });

  Log::Log4perl::init(\$log_config);

  $this->_make_dir("$Bin/../logs");
  $this->_make_dir("$Bin/../logs/$release");

  my $root_log = new IO::File ">> $Bin/../logs/$release/$release.log";
  $this->{master_log} = $root_log;
  print $root_log "starting $step...\n";

  #  my $cfg = Config::Any->load_files({files =>  [ "Config.pm" ],use_ext => 1 });
  #    print Config::Any->extensions;
  #    print Config::Any->finder;
  #    print Config::Any->plugins;
  #    my $cfg = Config::Any::Perl->load("site_config.pl");
  #  print $cfg;
  
  return $this;
}

sub execute {
  my $self = shift;
  $self->logit->info('BEGIN STEP: ' . $self->step);
  $self->run();
  $self->logit->info('END STEP  : ' . $self->step);
}

sub logit {
  my $self = shift;
  my $logger = Log::Log4perl->get_logger('rootLogger');
  return $logger;
}

sub master_log { return shift->{master_log}; }

sub mirror_directory {
    my ($self,$path,$local_mirror_path) = @_;
    
    my $release    = $self->release;
    my $release_id = $self->release_id;
    
    my $contact_email = $self->contact_email;
    my $ftp_server    = $self->remote_ftp_server;
    
    $self->_reset_dir($local_mirror_path);
    
    my $cwd = getcwd();
    $self->logit->info("  mirroring directory $path from $ftp_server to $local_mirror_path");
    chdir $local_mirror_path or $self->logit->logdie("cannot chdir to local mirror directory: $local_mirror_path");
    
    my $ftp = Net::FTP::Recursive->new($ftp_server, Debug => 0) or $self->logit->logdie("can't instantiate Net::FTP object");
    $ftp->login('anonymous', $contact_email) or $self->logit->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->logit->warn("couldn't switch to binary mode for FTP");
    $ftp->cwd($path)                         or $self->logit->error("cannot chdir to remote dir ($path)") && return;
    my $r = $ftp->rget(); 
    $ftp->quit;
    $self->logit->info("  mirroring directory: complete");
}

sub mirror_file {
    my ($self,$path,$remote_file,$local_mirror_path) = @_;
    
    my $release    = $self->release;
    my $release_id = $self->release_id;
    
    my $contact_email = $self->contact_email;
    my $ftp_server    = $self->remote_ftp_server;
    
    $self->logit->info("  mirroring $path/$remote_file from $ftp_server to $local_mirror_path");  
    
    my $cwd = getcwd();
    chdir $local_mirror_path or $self->logit->warn("cannot chdir to local mirror directory: $local_mirror_path");
    
    my $ftp = Net::FTP->new($ftp_server, Debug => 0) or $self->logit->logdie("cannot construct Net::FTP object");
    $ftp->login('anonymous', $contact_email) or $self->logit->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->logit->warn("couldn't switch to binary mode for FTP");
    $ftp->cwd($path)                         or $self->logit->error("cannot chdir to remote dir ($path)");
    $ftp->get($remote_file)                  or $self->logit->error("cannot fetch to $remote_file");
    $ftp->quit;
    $self->logit->info("  mirroring $path/$remote_file: complete");
}


sub mirror_genomic_sequence {
    my ($self,$species) = @_;  
    $self->logit->debug("mirroring genomic sequence for $species");  
    
    my $release            = $self->release;
    my $ftp_remote_dir     = $self->remote_ftp_path . "/$release/genomes/$species/sequences/dna";
    my $local_mirror_dir = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequences/dna");
        
    # Create (or copy) a concatenated file to the FTP site
    my $custom_filename = $self->get_filename('genomic_fasta_archive',$species);
    my $target_file = "$local_mirror_dir/$custom_filename";
    
    # Mirror the file(s) unless we already have it(them)
#    unless (-e "$target_file.gz") {
    $self->mirror_file($ftp_remote_dir,$custom_filename . ".gz",$local_mirror_dir);
	
#	# Is this a non-standard filename or path? Maybe just a single file instead of a directory?
#	my $concatenate_target = $self->mirror_dir;
#	if (my $file = $self->config->{species_info}->{$species}->{remote_dna_filename}) {
#	    $self->mirror_file($ftp_remote_dir,$file,$local_mirror_dir);
#	    $concatenate_target .= "/$file";
#	} else {
#	    $self->mirror_file($ftp_remote_dir,$custom_filename . ".gz",$local_mirror_dir);
#	    $concatenate_target .= "/$file";
#	}
# else {
#	    $self->mirror_directory($ftp_remote_dir,$local_mirror_dir);	
#	}
	
#	# Create the concatenated file on the FTP site
    # No longer any need to do this
#	$self->concatenate_fasta($concatenate_target,
#				 $target_file,
#				 $species);
	
	my $custom_fasta = $self->get_filename('genomic_fasta_archive',$species);
    
    # Sanitize elegans
    if ($species =~ /elegans/) {
	chdir (join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequence/dna"));
	system ("mv $custom_fasta.gz temp.fa.gz");
	system ("gunzip -c temp.fa.gz | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > $custom_fasta.gz");
    }
    
    $self->update_symlink({path    => join("/",
					   $self->ftp_root,
					   $self->local_ftp_path,
					   "genomes/$species/sequences/dna"),
			   target  => "$custom_fasta.gz",
			   symlink => 'current.dna.fa.gz',
		       });	
#    }
    $self->logit->debug("mirroring genomic sequence for $species: complete");
}

sub mirror_gff_tables {
    my ($self,$species) = @_;  
    $self->logit->debug("mirroring gff files for $species");  
    
    my $release            = $self->release;
    my $ftp_remote_dir     = $self->remote_ftp_path . "/$release/genomes/$species/genome_feature_tables/GFF2";

    # Mirror the genomic annotations directly to the FTP site
#    my $local_mirror_dir   = $self->mirror_dir;
    my $local_mirror_dir = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/genome_feature_tables/GFF2");
    
    my $gff_filename   = $self->get_filename('genomic_gff2_archive',$species);    # Filename of the GFF2 archive
    
    # Mirror the file(s) unless we already have it(them)
#    unless (-e "$target_file.gz") {
    $self->mirror_file($ftp_remote_dir,$gff_filename . ".gz",$local_mirror_dir);
# }

    $self->logit->debug("mirroring gff files for $species: complete");
}

sub update_symlink {
  my ($self,$params) = @_;
  my $target  = $params->{target};
  my $path    = $params->{path};
  my $symlink = $params->{symlink};
  
  $self->logit->debug("updating symlink $path: $symlink -> $target");
  
  chdir($path);
  unlink($symlink)          or $self->logit->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
  symlink($target,$symlink) or $self->logit->warn("creating symlink $symlink -> $target FAILED");
  $self->logit->debug("updating symlink $path: $symlink -> $target: complete");
}

sub unpack_archived_sequence {
  my ($self,$params) = @_;
  my $species = $params->{species};
  my $type    = $params->{type};
  $self->logit->debug("unpacking archived sequence for $species");

  # Other species besides elegans, briggsae, remanei
  # Fetch the most current archived DNA
  # Concatenate it to the blast directory.
  my $archived_dna = $self->config->{species_info}->{$species}->{"local_$type " . "_filename"};
  my $src = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/$archived_dna");
  
  $self->concatenate_fasta($src,
			   $params->{target_file},			  
			   $species);
  
  chdir($self->species_root) or $self->logit->logdie("couldn't chdir to $self->species_root");
  system("gunzip $params->{target_file}.gz");
  
  $self->logit->debug("unpacking archived sequence for $species: complete");
}    



sub _reset_dir {
    my ($self,$target) = @_;
        
    $target =~ /\S+/ or return;
    
#    $self->_remove_dir($target) or return;
    $self->_make_dir($target) or return;    
    return 1;
}

sub _remove_dir {
    my ($self,$target) = @_;

    $target =~ /\S+/ or return;
    $self->logit->warn("trying to remove $target directory which doesn't exist") unless -e $target;
    system ("rm -rf $target") or $self->logit->warn("couldn't remove the $target directory");
    return 1;
}

sub _make_dir {
  my ($self,$target) = @_;
  
  $target =~ /\S+/ or return;
  if (-e $target) {
    $self->logit->warn("trying to create $target directory, which already exists");
    return 1;
  }
  mkdir $target, 0775;
  return 1;
}


sub get_filename {
  my ($self,$type,$species) = @_;

  # Custom filenames with inserted values.
  my $filename;
  if ($type && $species) {
    $filename = sprintf($self->config->{filenames}->{custom}->{$type},$species,$self->release);
  } else {
    $filename = $self->config->{filenames}->{generic}->{$type};
  }
  $self->logit->logdie("Couldn't fetch a suitable output filename for $type:$species") unless $filename;
  return $filename;
}

# Parse the species from a g_species string
sub species_alone {
  my ($self,$species) = @_;
  $species =~ /\w_(.*)/;

  # Sanger FTP site structure is inconsistent.
  return 'brugia'          if $species eq 'b_malayi';
  return 'heterorhabditis' if $species eq 'h_bacteriophora';
  return 'pristionchus'    if $species eq 'p_pacificus';
  
  return $1;
}


# Accessors
sub support_dbs {
  my $self = shift;
  my $root = $config{root};
  return "$root/$config{directories}{support_dbs}";
}

sub tarballs_dir {
  my $self   = shift;
  my $dir    = $config{directories}{database_tarballs};
  return join("/",$self->ftp_root,$self->local_ftp_path,$dir);
}

sub get_blatdb_dir {
  my $self        = shift;    
  my $release     = $self->release;
  my $support_db  = $self->support_dbs;
  my $blatdb_dir = "$support_db/$release/blat";
  $self->_make_dir("$support_db/$release");
  $self->_make_dir($blatdb_dir);
  return $blatdb_dir;
}

sub get_blastdb_dir {
  my $self        = shift;    
  my $release     = $self->release;
  my $support_db  = $self->support_dbs;
  my $blastdb_dir = "$support_db/$release/blast";
  $self->_make_dir("$support_db/$release");
  $self->_make_dir($blastdb_dir);
  return $blastdb_dir;
}

sub get_epcr_dir {
  my $self        = shift;    
  my $release     = $self->release;
  my $support_db  = $self->support_dbs;
  my $epcr_dir = "$support_db/$release/epcr";
  $self->_make_dir("$support_db/$release");
  $self->_make_dir($epcr_dir);
  return $epcr_dir;
}

sub bin_root { return $Bin; }
sub release  { return shift->{release}; };
sub release_id {
  my $self = shift;
  my $release = $self->release;
  $release =~ /WS(.*)/;
  return $1;
}

sub config {
  return shift->{config};
}

sub species {
    my $self = shift;
    my @species = keys %{$self->config->{species_info}};
    return \@species;
}

sub concatenate_fasta {
    my ($self,$in,$out,$species) = @_;
    $self->logit->debug("concatenating FASTA files");
    
    system("gzip -f $in/*");
    my @files;
    # May have been passed a file instead of a directory
    if ($in =~ /.*gz/) {
	push @files,$in;
    } else {
	@files = glob("$in/*.dna.gz");
    }
    
    # purge
    @files = grep { !/intergenic|masked/ } @files;
    
    my $files = join(' ', @files);
    
    #    my $cmd = qq[(zcat $files > $out.tmp) >& $out.err];
    system("(zcat $files > $out.tmp) >& $out.err");
    
    my $err = slurp("$out.err");
    print STDERR $err;
    unlink "$out.err";
    
    open(OUT, ">$out")    or $self->logit->fatal("cannot write $out: $!") && die;
    open(IN, "<$out.tmp") or $self->logit->fatal("cannot read $out.tmp: $!") && die;
    
    while (<IN>) {
#    s/^>([IVX]+|MtDNA)/>CHROMOSOME_$1/ if $species =~ /elegans/;
	s/CHROMOSOME_// if $species =~ /elegans/;
	print OUT $_;
    }
  
    close IN;
    close OUT;
    unlink "$out.tmp";
    system("gzip -f $out");
    $self->logit->debug("concatenating files for $species: complete");
}


sub AUTOLOAD {
    my ($self,$args) = @_;

    my $name = $AUTOLOAD;    
    $name =~ s/.*://;   # strip fully-qualified portion
    
    if ($args) {
      $config{$name} = $args;
#      $self->{$name} = $value;
      return;
    }

#    if (ref $self->{$name} =~ /ARRAY/) {
#      return @{$self->{$name}};
#    } else {
#      return $self->{$name};
#    }

    return $config{$name};
    
    if (ref $self->{$name} =~ /ARRAY/) {
      return @{$self->{$name}};
    } else {
      return $self->{$name};
    }
}
    

1;
