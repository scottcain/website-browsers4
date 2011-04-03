package WormBase::Update;

use local::lib '/usr/local/wormbase/website/classic/extlib';

use Net::FTP::Recursive;
use Log::Log4perl;
use FindBin qw($Bin);
use IO::File;
our $AUTOLOAD;



use Moose;

# Don't run any substantial commands when dryrun is true.
has 'dryrun' => (
    is => 'rw',
    default => 0 );

has 'version' => (
    is        => 'rw',
    required  => 1,
    default   => 'WS1',
    );

   
has 'bin_path' => (
    is => 'ro',
    default => sub {
	use FindBin qw/$Bin/;
	return $Bin;
    },
    );

# Logging options
has 'log_dir' => (
    is => 'ro',
    default => '/usr/local/wormbase/logs/updates',
    );


has 'log' => (
    is => 'ro',
    lazy_build => 1,
);


sub _build_log {
    my $self    = shift;
    my $version = $self->version;
    my $step    = $self->step;
    my $log_dir = $self->log_dir;    
    # Make sure that our log dirs exist
    $self->_make_dir($self->log_dir);
    $self->_make_dir($self->log_dir . "/$version");

    my $log_config = qq(
	
		log4perl.logger.rootLogger  = INFO,LOGFILE,Screen
		
		# Global spacing
		log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
		log4perl.appender.LOGFILE.filename=$log_dir/$version/$step.log
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
								   return " "     if $priority eq 'INFO';
								   return "  ! "  if $priority eq 'WARN';  # potential errors
								   return " !! "  if $priority eq 'ERROR'; # errors
								   return "!!! "  if $priority eq 'FATAL';  # fatal errors
								   return " ";
							   });
    
    Log::Log4perl::init(\$log_config) or die "Couldn't create the Log::Log4Perl object";
        
    my $logger = Log::Log4perl->get_logger('rootLogger');
    return $logger;	
}


has 'master_log' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_master_log {
    my $self     = shift;
    my $version  = $self->version;
    my $log      = $self->log_dir . "/$version.log";
    my $root_log = new IO::File ">>$log";
    return $root_log;
}


# Configuration options
has 'root_path' => (
    is      => 'ro',
    default => '/usr/local/wormbase' );

has 'ftp_path' => (
    is      => 'ro',
    default => '/usr/local/ftp/pub/wormbase'
    );

has 'ftp_species_path' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_ftp_species_path {
    my $self = shift;
    my $version = $self->version;
    return $self->ftp_path . "/releases/$version/species";
}

# A dsicoverable list of species (symbolic) names.
# Used later to auto-construct filenames.
has 'species_list' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_species_list {
    my $self = shift;
    my $species_path = $self->ftp_species_path;
    opendir(DIR,"$species_path") or die "Couldn't open the species directory ($species_path) on the FTP site.";
    my @species = grep { !/^\./ && -d "$species_path/$_" } readdir(DIR);
    return @species;
}


has 'tmp_staging_path' => (
    is => 'ro',
    default => sub {
	my $self = shift;
	return $self->root_path . "/tmp/staging";
    } );

has 'support_databases_path' => (
    is => 'ro',
    default => sub {
	my $self = shift;
	return $self->root_path . "/databases";
    } );

has 'acedb_path' => (
    is => 'ro',
    default => sub {
	my $self = shift;
	return $self->root_path . "/acedb";
    }
    );

has 'acedb_group' => (
    is => 'ro',
    default => 'acedb' );

has 'mysql_data_path' => (
    is => 'ro',
    default => '/usr/local/mysq/data',
    );

has 'mysql_user' => (
    is => 'ro',
    default => 'root',
    );
    
has 'mysql_pass' => (
    is => 'ro',
    default => '3l3g@nz',
    );

has 'mysql_host' => (
    is => 'ro',
    default => 'localhost',
    );


# The web user for database privileges
has 'web_user' => (
    is      => 'ro',
    default => 'nobody',
    ); 


my %config =  (
	       directories => {
####			       support_dbs => "databases",
			       database_tarballs => 'mirror/database_tarballs',
			      }	,
	       
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
 		   # added for WS204 and up...
 		   m_hapla => {
 		       #remote_gff2_filename    => '',
		       remote_dna_filename     => 'm_hapla.%s.dna.gz'
 		    },
			m_incognita => {
 		      
 		      remote_dna_filename     => 'm_incogita.%s.dna.gz'
 		    },
	       },
	       
	       fatonib => '/usr/local/blat/bin/faToNib',
	       
	      );


sub execute {
  my $self = shift;
  $self->log->info('BEGIN STEP: ' . $self->step);

  # Subclasses should implement the run() method.
  $self->run();
  $self->log->info('END STEP  : ' . $self->step);
}



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
    
    my $ftp = Net::FTP::Recursive->new($ftp_server, Debug => 0, Passive => 1) or $self->logit->logdie("can't instantiate Net::FTP object");
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
    
    my $ftp = Net::FTP->new($ftp_server, Debug => 0, Passive => 1) or $self->logit->logdie("cannot construct Net::FTP object");
    $ftp->login('anonymous', $contact_email) or $self->logit->logdie("cannot login to remote FTP server");
    $ftp->binary()                           or $self->logit->warn("couldn't switch to binary mode for FTP");
    $ftp->cwd($path)                         or $self->logit->error("cannot chdir to remote dir ($path)");
    $ftp->get($remote_file)                  or $self->logit->error("cannot fetch to $remote_file");
    $ftp->quit;
    $self->logit->info("  mirroring $path/$remote_file: complete");
}


# Here's how to fix C. elegans seuqence...    
#    # Sanitize elegans
#    if ($species =~ /elegans/) {
#	chdir (join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/sequence/dna"));
#	system ("mv $custom_fasta.gz temp.fa.gz");
#	system ("gunzip -c temp.fa.gz | perl -p -i -e 's/CHROMOSOME_//g' | gzip -c > $custom_fasta.gz");
#    }
#    
#    $self->update_symlink({path    => join("/",
#					   $self->ftp_root,
#					   $self->local_ftp_path,
#					   "genomes/$species/sequences/dna"),
#			   target  => "$custom_fasta.gz",
#			   symlink => 'current.dna.fa.gz',
#		       });	

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




# RETAIN
sub release_id {
  my $self = shift;
  my $release = $self->release;
  $release =~ /WS(.*)/;
  return $1;
}




# Dump out C. elegans ESTs suitable for BLAST searching
# and for loading into GFF DB.
# Should be a role, but this is expedient for now.
sub dump_elegans_ests {
    my $self = shift;
    $self->log->info("BEGIN: dumping ESTs for C. elegans");
    return if $self->dryrun;

    use Ace;
    $|++;
    
    # connect to database
    my $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
    
    my $debug_counter;
    
    my $query = <<END;
find cDNA_Sequence ; >DNA
END
;
    
#my @seqs = $db->fetch(-query=>qq{find cDNA_Sequence; dna; query find 
#NDB_Sequence; dna"});
    my @seqs = $db->fetch(-query=>$query);
    my $file = join("/",$self->ftp_species_path,$self->version,'c_elegans','c_elegans.' . $self->version . ".ests.fa.gz");
    open OUT," | gzip -c > $file" or $self->log->logdie("Couldn't open $file for generating the EST file dump");
    
    foreach (@seqs) {
	$debug_counter++;
	if ($debug_counter % 1000 == 0) {
	    print STDERR "$debug_counter - [$_] ...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
    	
	$_ =~ s/\0+\Z//; # get rid of nulls in data stream!
	$_ =~ s!^//.*!!gm;
	my $dna = $_->asDNA();
	print OUT $dna if $dna;
    }
    close OUT;
    $self->log->info("END: dumping ESTs for C. elegans");
}






1;
