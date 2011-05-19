package WormBase::Update;

use local::lib '/usr/local/wormbase/website/classic/extlib';

use Log::Log4perl;
use FindBin qw($Bin);

use Moose;
extends qw/WormBase/;

with 'WormBase::Roles::Config';
   
has 'blastdb_format_script' => (
    is => 'ro',
    default => '/usr/local/blast/bin/formatdb',
    );

has 'bin_path' => (
    is => 'ro',
    default => sub {
	use FindBin qw/$Bin/;
	return $Bin;
    },
    );

# I should break this into STDERR and STDOUT logs.
has 'log' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_log {
    my $self    = shift;
    my $release = $self->release;
    my $step    = $self->step;
    $step =~ s/ /_/g;
    my $log_dir = $self->log_dir;    
    # Make sure that our log dirs exist
    $self->_make_dir($self->log_dir);
    $self->_make_dir($self->log_dir . "/$release");
    
    $self->_make_dir($self->log_dir . "/$release/steps");
    $self->_make_dir($self->log_dir . "/$release/steps/$step");

    my $log_config = qq(

		log4perl.rootLogger=INFO, MASTERLOG, MASTERERR, STEPLOG, STEPERR, SCREEN

                # MatchTRACE: lowest level for the STEPLOG
                log4perl.filter.MatchTRACE = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchTRACE.LevelToMatch = TRACE
                log4perl.filter.MatchTRACE.AcceptOnMatch = true

                # MatchWARN: Exact match for warnings
                log4perl.filter.MatchWARN = Log::Log4perl::Filter::LevelMatch
                log4perl.filter.MatchWARN.LevelToMatch = WARN
                log4perl.filter.MatchWARN.AcceptOnMatch = true

                # MatchERROR: ERROR and UP
                log4perl.filter.MatchERROR = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchERROR.LevelMin = ERROR
                log4perl.filter.MatchERROR.AcceptOnMatch = true

                # MatchINFO: INFO and UP. For SCREEN.
                log4perl.filter.MatchINFO = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchINFO.LevelMin = INFO
                log4perl.filter.MatchINFO.AcceptOnMatch = true

                # The SCREEN
                log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
                log4perl.appender.SCREEN.mode      = append
                log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.SCREEN.layout.ConversionPattern=[%d %r]%K%F %L %c − %m%n
		log4perl.appender.SCREEN.layout.ConversionPattern=[%d %p]%K%m %n
#		log4perl.appender.Screen.stderr  = 0
                log4perl.appender.SCREEN.Filter   = MatchINFO
         
                # The MASTERLOG: INFO, WARN, ERROR, FATAL
		log4perl.appender.MASTERLOG=Log::Log4perl::Appender::File
		log4perl.appender.MASTERLOG.filename=$log_dir/$release/master.log
		log4perl.appender.MASTERLOG.mode=append
		log4perl.appender.MASTERLOG.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.MASTERLOG.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
                log4perl.appender.MASTERLOG.Filter   = MatchINFO


                # The MASTERERR: ERROR, FATAL
		log4perl.appender.MASTERERR=Log::Log4perl::Appender::File
		log4perl.appender.MASTERERR.filename=$log_dir/$release/master.err
		log4perl.appender.MASTERERR.mode=append
		log4perl.appender.MASTERERR.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.MASTERERR.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
                log4perl.appender.MASTERERR.Filter   = MatchERROR

                # The STEPLOG: TRACE to get everything.
		log4perl.appender.STEPLOG=Log::Log4perl::Appender::File
		log4perl.appender.STEPLOG.filename=$log_dir/$release/steps/$step/step.log
		log4perl.appender.STEPLOG.mode=append
		log4perl.appender.STEPLOG.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
		log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K %n	       
                log4perl.appender.STEPLOG.Filter   = MatchTRACE

                # The STEPERR: ERROR and up
		log4perl.appender.STEPERR=Log::Log4perl::Appender::File
		log4perl.appender.STEPERR.filename=$log_dir/$release/steps/$step/step.err
		log4perl.appender.STEPERR.mode=append
		log4perl.appender.STEPERR.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
		log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K %n	       
                log4perl.appender.STEPERR.Filter   = MatchERROR
		);
    
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('K',
							       sub {
								   
								   my ($layout, $message, $category, $priority, $caller_level) = @_;
								   # FATAL, ERROR, WARN, INFO, DEBUG, TRACE
								   return "    "  if $priority eq 'DEBUG';
								   return "    "  if $priority eq 'INFO';
								   return "  "  if $priority eq 'WARN';  # potential errors
								   return " !  "  if $priority eq 'ERROR'; # errors
								   return " !  "  if $priority eq 'FATAL';  # fatal errors
								   return "    ";
							   });
    
    Log::Log4perl::init(\$log_config) or die "Couldn't create the Log::Log4Perl object";
        
    my $logger = Log::Log4perl->get_logger('rootLogger');
    return $logger;	
}


# Logging options
has 'log_dir' => (
    is => 'ro',
    default => '/usr/local/wormbase/logs/staging',
    );


####################
#
# Helper scripts
#
####################

has 'create_blastdb_script' => ( 
    is => 'ro',     
    default => sub {
	my $self = shift;
	my $bin = $self->bin_path;
	my $script = "$bin/../helpers/create_blast_db.sh"
    });



# The web user for database privileges
has 'web_user' => (
    is      => 'ro',
    default => 'nobody',
    ); 




sub execute {
  my $self = shift;
  $self->log->warn('BEGIN : ' . $self->step);
  # Subclasses should implement the run() method.
  $self->run();
  $self->log->warn('END : ' . $self->step);
}

# When running the staging code automatically, we need to 
# discover what the next release of the database is.
# To do this, we get a list of the releases we already have
# have on the FTP site then autoincrement.
# This needs to be done BEFORE execute so that we can set 
# up appropriate log files.
# Really, this should only be called by the first step in the
# staging process.  After that, each step will be passed
# the current release being staged.
before 'execute' => sub {
    my $self  = shift;

    # We provided a release. We're good to execute.
    return if $self->release;

    # Maybe we didn't provide a release. This only
    # makes sense in the context of automatic mirroring.
    unless ($self->step =~ /mirror/) {
	$self->log->logdie("no release provided; discovering a new release only makes sense during the mirroring step.");
    }

    my $releases = $self->existing_releases;
    
    # Save the most current release.
    $self->release($releases->[-1]);
    
    # Get its ID
    my $last_release_id = $self->release_id;
    
    # Increment and save.
    my $target_release_id = ++$last_release_id;
    $self->release("WS$target_release_id");
    return;
};




sub update_symlink {
  my ($self,$params) = @_;
  my $target  = $params->{target};
  my $path    = $params->{path};
  my $symlink = $params->{symlink};
  
  $self->log->debug("updating symlink $path: $symlink -> $target");
  
  chdir($path);
  unlink($symlink)          or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
  symlink($target,$symlink) or $self->log->warn("creating symlink $symlink -> $target FAILED");
  $self->log->debug("updating symlink $path: $symlink -> $target: complete");
}

sub unpack_archived_sequence {
  my ($self,$params) = @_;
  my $species = $params->{species};
  my $type    = $params->{type};
  $self->log->debug("unpacking archived sequence for $species");

  # Other species besides elegans, briggsae, remanei
  # Fetch the most current archived DNA
  # Concatenate it to the blast directory.
  my $archived_dna = $self->config->{species_info}->{$species}->{"local_$type " . "_filename"};
  my $src = join("/",$self->ftp_root,$self->local_ftp_path,"genomes/$species/$archived_dna");
  
  
  chdir($self->species_root) or $self->log->logdie("couldn't chdir to $self->species_root");
  system("gunzip $params->{target_file}.gz");
  
  $self->log->debug("unpacking archived sequence for $species: complete");
}    





# Dump out C. elegans ESTs suitable for BLAST searching
# and for loading into GFF DB.
# Should be a role, but this is expedient for now.
sub dump_elegans_ests {
    my $self = shift;
    $self->log->debug("begin: dumping ESTs for C. elegans");

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
    my $file = join("/",$self->ftp_releases_dir,'species','c_elegans','c_elegans.' . $self->release . ".ests.fa.gz");
    open OUT," | gzip -c > $file" or $self->log->logdie("Couldn't open $file for generating the EST file dump");
    
    foreach (@seqs) {
	$debug_counter++;
	if ($debug_counter % 10000 == 0) {
	    print STDERR "$debug_counter - [$_] ...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
    	
	$_ =~ s/\0+\Z//; # get rid of nulls in data stream!
	$_ =~ s!^//.*!!gm;
	my $dna = $_->asDNA();
	print OUT $dna if $dna;
    }
    close OUT;
    $self->log->debug("end: dumping ESTs for C. elegans");
}



sub system_call {
    my ($self,$cmd,$msg) = @_;
    my $result = system($cmd);
    if ($result == 0) {
	$self->log->debug("$msg: succeeded");
    } else {
	$self->log->logdie("$msg: failed");
    }
}


################# CRUFT


# Check to see if input files exist
sub check_input_file {
    my ($self,$file,$step) = @_;
    return 1 if (-e $file);
    $self->log->logdie("The input file ($file) for $step does not exist. Please fix.");
    return 0;
}




1;
