package WormBase::Update;

use local::lib '/usr/local/wormbase/website/classic/extlib';

use Log::Log4perl;
use FindBin qw($Bin);
use IO::File;

use Moose;

with 'WormBase::Update::Config'; # A basic Log::Log4perl screen appender

# Don't run any substantial commands when dryrun is true.
has 'dryrun' => (
    is => 'rw',
    default => 0 );

has 'release' => (
    is        => 'rw',
    );

sub release_id {
    my $self    = shift;
    my $release = shift || $self->release;
    $release =~ /WS(.*)/ if $release;
    return $1;
} 


# Some convenience accessors
# Simple accessor/getter for species so I don't have to pass it around.
has 'species' => (
    is => 'rw'
    );

has 'db_symbolic_name' => (
    is => 'rw',
    lazy_build => 1 );

sub _build_db_symbolic_name {
    my $self    = shift;
    my $species = shift;
    my $version = $self->version;
    return $species . '_' . $version;
}

   
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

		log4perl.logger=ALL, UpdateLog, UpdateError, Screen, MasterLog

                # Filters to break up logging into different files
                # Filter to match level ERROR - Critical errors
                log4perl.filter.MatchError = Log::Log4perl::Filter::LevelMatch
                log4perl.filter.MatchError.LevelToMatch  = ERROR
                log4perl.filter.MatchError.AcceptOnMatch = true

                # Filter to match level INFO
                log4perl.filter.MatchInfo  = Log::Log4perl::Filter::LevelMatch
                log4perl.filter.MatchInfo.LevelToMatch  = INFO
                log4perl.filter.MatchInfo.AcceptOnMatch = true
		
                # step.err
		log4perl.appender.UpdateError=Log::Log4perl::Appender::File
		log4perl.appender.UpdateError.filename=$log_dir/$release/steps/$step/step.err
                log4perl.appender.UpdateError.Threshold=WARN
		log4perl.appender.UpdateError.mode=append
		log4perl.appender.UpdateError.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.UpdateError.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
		log4perl.appender.UpdateError.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.UpdateError.layout.ConversionPattern=[%d %p]%K %n	       
                log4perl.appender.UpdateError.Filter = MatchError

                # $step.log
		log4perl.appender.UpdateLog=Log::Log4perl::Appender::File
		log4perl.appender.UpdateLog.filename=$log_dir/$release/steps/$step/step.log
		log4perl.appender.UpdateLog.mode=append
                log4perl.appender.UpdateError.Threshold=ALL
		log4perl.appender.UpdateLog.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.UpdateLog.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
		log4perl.appender.UpdateLog.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.UpdateLog.layout.ConversionPattern=[%d %p]%K %n	       
                # log4perl.appender.UpdateLog.Filter = MatchInfo
	
		log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
		log4perl.appender.Screen.stderr  = 0
                log4perl.appender.UpdateError.Threshold=INFO
		log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.Screen.layout.ConversionPattern=[%d %r]%K%F %L %c − %m%n
		log4perl.appender.Screen.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.Screen.layout.ConversionPattern=[%d %p]%K %n


		log4perl.appender.MasterLog=Log::Log4perl::Appender::File
		log4perl.appender.MasterLog.filename=$log_dir/$release/master.log
		log4perl.appender.MasterLog.mode=append
                log4perl.appender.UpdateError.Threshold=INFO
		log4perl.appender.MasterLog.layout = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.MasterLog.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
		log4perl.appender.MasterLog.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
		#log4perl.appender.MasterLog.layout.ConversionPattern=[%d %p]%K %n
#                # Filter for my MasterLog
                log4perl.filter.MasterLogFilter    = sub { /LOG/ }
                log4perl.appender.MasterLog.Filter = MasterLogFilter

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



# The web user for database privileges
has 'web_user' => (
    is      => 'ro',
    default => 'nobody',
    ); 




sub execute {
  my $self = shift;
  $self->log->info('LOG: BEGIN  : ' . $self->step);
  # Subclasses should implement the run() method.
  $self->run();
  $self->log->info('LOG: END    : ' . $self->step);
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


# Dump out C. elegans ESTs suitable for BLAST searching
# and for loading into GFF DB.
# Should be a role, but this is expedient for now.
sub dump_elegans_ests {
    my $self = shift;
    $self->log->debug("begin: dumping ESTs for C. elegans");
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
    my $file = join("/",$self->ftp_species_path,'c_elegans','c_elegans.' . $self->release . ".ests.fa.gz");
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







################# CRUFT


# Check to see if input files exist
sub check_input_file {
    my ($self,$file,$step) = @_;
    return 1 if (-e $file);
    $self->log->logdie("The input file ($file) for $step does not exist. Please fix.");
    return 0;
}




1;
