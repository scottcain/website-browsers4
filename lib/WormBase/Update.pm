package WormBase::Update;

use Time::HiRes qw(gettimeofday tv_interval);

use Digest::MD5;
use Log::Log4perl;
use FindBin qw($Bin);

use Moose;
use JSON::Any qw/XS JSON/;
extends qw/WormBase/;

with qw/WormBase::Roles::Config/;

has 'blastdb_format_script' => (
    is => 'ro',
    default => '/usr/local/wormbase/services/blast/bin/formatdb',
    );

has 'bin_path' => (
    is => 'ro',
    default => sub {
	use FindBin qw/$Bin/;
	return $Bin;
    },
    );



has 'assemblies_metadata' => (
    is => 'ro',
    lazy_build => 1 );

sub _build_assemblies_metadata {
    my $self = shift;
    my $release = $self->release;
    my $releases_dir = $self->ftp_releases_dir;
    my $assemblies_file = "$releases_dir/$release/species/ASSEMBLIES.$release.json";

    my $j = JSON::Any->new;
    
    open( FILE, '<', $assemblies_file ) or $self->log->logdie("Could not open the file: $!");

    undef $/;
    my $json = <FILE>;
    my $obj = $j->jsonToObj($json);
    return $obj;
}
    
	


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

has 'status' => (
    is => 'ro',
    );


# default step
has 'step' => (
    is => 'ro',
    default => 'generic step',
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
	my $bin = $self->bin_path || '.';
	my $script = "$bin/../helpers/create_blast_db.sh";
    });



# The web user for database privileges
has 'web_user' => (
    is      => 'ro',
    default => 'nobody',
    ); 


 


sub execute {
    my $self = shift;
    my $start = [gettimeofday]; # starting time
    
    $self->log->warn('BEGIN : ' . $self->step);
    # Subclasses should implement the run() method.
    $self->run();
    
    my $end = [gettimeofday];
    my $interval = tv_interval($start,$end);
    my $time = $self->sec2human($interval);
    
    $self->log->warn('END : ' . $self->step . "; in $time");
}


sub sec2human {
    my ($self,$secs) = @_;
    my ($dd,$hh,$mm,$ss) = (gmtime $secs)[7,2,1,0];
    my $time = sprintf("%d days, %d hours, %d minutes and %d seconds",$dd,$hh,$mm,$ss);
    return $time;
}


# We want some steps to run without having to require a specific
# release (such as pushing software or mirroring a new release).
# Some steps need to know what the current STAGED version is
# (for example, mirroring should look to see if a NEW version has
# arrived).
# Other steps need to know what the current production version is.

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
    # makes sense in the context of certain steps.
    if ($self->step eq 'deploying a new version of the webapp') {
	# Get the current version of acedb on either staging or production.
	my $host = ($self->target eq 'production')
	    ? 'www.wormbase.org'
	    : 'staging.wormbase.org';

	# This WON'T be correct for the first software push at a new release.
	my $json = `curl -X GET -H content-type:application/json http://$host/rest/version`;
	$json =~ /.*(WS\d\d\d)"}/;
	my $version = $1;
	$self->release($version);
	return $version;
    }
    
    if ( $self->step eq 'push acedb to production'
	 || $self->step eq 'push support databases to production'
	 || $self->step eq 'update symlinks on the production FTP site'
	 || $self->step =~ /mirror/   # mirror everything, not just next release.
	) {
	$self->release('release_independent_step');
	return;
    } elsif ($self->step =~ /check/ || $self->step =~ /mirror/) {
    } else {
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
    return "WS$target_release_id";
};





# Update symlinks to the current development or production version
# as appropriate.  Type should be set to production or development.
sub update_ftp_site_symlinks {
    my $self = shift;
    my $status       = $self->status;
    my $releases_dir = $self->ftp_releases_dir;
    my $species_dir  = $self->ftp_species_dir;
    
    # If provided, update symlinks on the FTP site
    # for that release.  Otherwise, walk through
    # the releases directory to rebuild symbolic structure.
    my $release = $self->release;

    chdir($releases_dir);
    if ($status eq 'development') {
	$self->update_symlink({target  => $release,
			       symlink => 'current-development-release',
			      });
    } elsif ($status eq 'production') {
	$self->update_symlink({target  => $release,
			       symlink => 'current-production-release',
			      });
    } else {
    }

    my @releases;
    if ($release eq 'release_independent_step') {
	@releases = glob("$releases_dir/*") or die "$!";
	$self->log->logdie("\n\nBecause of the introduction of BioProject IDs in WS237, this script can no longer keep the entire FTP site organized. Releases prior to WS237 will need to be organized manually.\n\n");
    } else {
	@releases = glob("$releases_dir/$release") or die "$!";
    }

    foreach my $release_path (@releases) {
	next unless $release_path =~ /.*WS\d\d.*/;    
	my @species = glob("$release_path/species/*");
	
	my ($release) = ($release_path =~ /.*(WS\d\d\d).*/);
	
	# Where should the release notes go?
	# chdir "$FTP_SPECIES_ROOT";

	my $metadata = $self->assemblies_metadata;
	
	foreach my $species_path (@species) {
	    next if $species_path =~ /README/;
	    next if $species_path =~ /ASSEMBLIES/;
	    
	    my ($species) = ($species_path =~ /.*\/(.*)/);

	    my $species_obj = WormBase->create('Species',{ symbolic_name => $species, 
							   release => $release });
	    # Now, for each species, iterate over the bioproject IDs.
	    # These are just strings.
	    
	    # NOTE: This can NO LONGER be used to organize the FTP site for
	    # releases prior to WS237. Don't even try it.
	    
	    my $bioprojects = $species_obj->bioprojects;
	    foreach my $bioproject (@$bioprojects) {

		my $bioproject_id = $bioproject->bioproject_id;

		# Is this the canonical bioproject?
		# For species labeled as is_canonical in metadata, assume that it is.
		# For species with a single bioproject, assume that it is.
		# We will create both:	
		# g_species.canonical_bioproject.current_development.gz and g_species.canonical_bioproject.current.gz
		# g_species.BPID.current_development.gz and g_species.BPID.current.gz
		# The species/*/* directories will themselves be flat with no
		# hierarchy for the bioproject ID.

		# This probably belongs in Species or Species/BioProject
		my $is_canonical;
		my @assemblies = @{$metadata->{$species}->{assemblies}};
		
		if (@assemblies == 1) {
		    $is_canonical++;
		} else {
		    foreach (@assemblies) {
			my $bioproject = $_->{bioproject};
			# Is the canonical flag set for this assembly?
			if ($bioproject eq $bioproject_id) {
			    if ($_->{is_canonical}) {
				$is_canonical++;
			    } 
			}
		    }
		}

		# Create a symlink to each file in /species	       
		opendir DIR,"$species_path/$bioproject_id" or die "Couldn't open the dir: $! $species_path/$bioproject_id";
		while (my $file = readdir(DIR)) {

		    # Uncomment this to use bioproject IDs in the
		    # symbolically organized species/ paths
#		my $species_source_path = "$species_path/$bioproject_id";
		    my $species_source_path = $species_path;
		    		
		    # Create some directories. Probably already exist.
		    system("mkdir -p $species_dir/$species");
		    chdir "$species_dir/$species";
		    mkdir("assemblies");
		    mkdir("gff");
		    mkdir("annotation");
		    mkdir("sequence");
		    
		    chdir "$species_dir/$species/sequence";
		    mkdir("genomic");
		    mkdir("transcripts");
		    mkdir("protein");
		    
		    
		    # GFF?
		    chdir "$species_dir/$species";
		    if ($file =~ /gff/) {
			chdir("gff") or die "$!";
			$self->update_symlink({target => "../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status  => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
			
		    } elsif ($file =~ /assembly/) {
			chdir("assemblies") or die "$!";
			$self->update_symlink({target => "../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status  => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
			
		    } elsif ($file =~ /genomic|sequence/) {
			chdir "$species_dir/$species/sequence/genomic" or die "$!";
			$self->update_symlink({target  => "../../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status  => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
			
		    } elsif ($file =~ /transcripts/) {
			chdir "$species_dir/$species/sequence/transcripts" or die "$! $species";
			$self->update_symlink({target  => "../../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status    => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
			
		    } elsif ($file =~ /wormpep|protein/) {
			chdir "$species_dir/$species/sequence/protein" or die "$!";
			$self->update_symlink({target  => "../../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status  => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
			
			# best_blast_hits isn't in the annotation/ folder
		    } elsif ($file =~ /best_blast/) {
			chdir "$species_dir/$species";
			mkdir("annotation");
			chdir("annotation");
			mkdir("best_blast_hits");
			chdir("best_blast_hits");
			$self->update_symlink({target  => "../../../../releases/$release/species/$species/$bioproject_id/$file",
					       symlink => $file,
					       release => $release,
					       status  => $status,
					       is_canonical => $is_canonical,
					       bioproject_id => $bioproject_id,
					      });
		    } else { }
		}
		
		# Annotations, but only those with the standard format.
#	chdir "$FTP_SPECIES_ROOT/$species";
		opendir DIR,"$species_path/$bioproject_id/annotation" or next;
		while (my $file = readdir(DIR)) {
		    next unless $file =~ /^$species/;
		    chdir "$species_dir/$species";
		    
		    mkdir("annotation");
		    chdir("annotation");
		    
		    my ($description) = ($file =~ /$species.*\.WS\d\d\d\.(.*?)\..*/);
		    mkdir($description);
		    chdir($description);
		    $self->update_symlink({target  => "../../../../releases/$release/species/$species/$bioproject_id/annotation/$file",
					   symlink => $file,
					   release => $release,
					   status  => $status,
					   is_canonical => $is_canonical,
					   bioproject_id => $bioproject_id,
					  });
		}
	    }
	}
    }
}



# Update a symlink to a file. If "release" is provided,
# assume that we also want to flag that file as the
# "current" version.
sub update_symlink {
    my ($self,$params) = @_;
    my $target  = $params->{target};
    my $release = $params->{release};
    my $symlink = $params->{symlink};
    my $status  = $params->{status};  # Set to development to provide links to current dev version.

    my $is_canonical = $params->{is_canonical};
    my $bioproject_id       = $params->{bioproject_id};
    $self->log->warn("updating $symlink -> $target");
    
    unlink($symlink)          or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
    symlink($target,$symlink) or $self->log->warn("couldn't create the $symlink");
    
    if ($release) {
	if ($status eq 'development') {
	    $symlink =~ s/$release/current_development/;
	} else {
	    $symlink =~ s/$release/current/;
	}
	unlink($symlink)           or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
	symlink($target,$symlink)  or $self->log->warn("couldn't create the current symlink");

	# Temporary to remove old "current" links
#	$symlink =~ s/$bioproject_id\.//;
#	unlink($symlink)           or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");	
#	$symlink =~ s/_development//;	
#	unlink($symlink)           or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
    }
    return;
    if ($is_canonical) {
	$symlink =~ s/$bioproject_id/canonical_bioproject/;

	unlink($symlink)           or $self->log->warn("couldn't unlink $symlink; perhaps it didn't exist to begin with");
	symlink($target,$symlink)  or $self->log->warn("couldn't create the current symlink");
    }

}




sub system_call {
    my ($self,$cmd,$msg) = @_;
    my $result = system($cmd);
    if ($result == 0) {
	$self->log->debug("$msg: $cmd succeeded");
    } else {
	$self->log->warn("$msg: $cmd failed");
    }
}

sub build_hash{
	my ($self, $file_name) = @_;
	open FILE, "<$file_name" or die "Cannot open the file: $file_name\n";
	my %hash;
	foreach my $line (<FILE>) {
	    chomp ($line);
	    my ($key, $value) = split '=>',$line;
	    $hash{$key} = $value;
	}
	return %hash;
}



# CHeck for the presence of the output file
# to avoid lengthy recomputes.
# Kludgy but mostly right.
sub check_output_file {
    my ($self,$file) = @_;
    if (-e $file && -s $file > 1000000) {
	$self->log->debug("output file already exists; skipping recompilation");
	return 1;
    } else {
	return 0;
    }
}



sub create_md5 {
  my ($self,$base,$file) = @_;

  $self->log->debug("creating md5 sum of $file");
  
  open(FILE, "$base/$file") or die "Can't open '$base/$file': $!";
  binmode(FILE);
  
  open OUT,">$base/$file.md5";
  print OUT Digest::MD5->new->addfile(*FILE)->hexdigest, "  $file\n";
  
  # Verify the checksum...
  chdir($base);
  my $result = `md5sum -c $file.md5`;
  die "Checksum does not match: packaging $file.tgz failed\n" if ($result =~ /failed/);
  return "$file.md5";
}




# CRUFT

# TH: 2011.06.04: Now provided as part of the build.
# Dump out C. elegans ESTs suitable for BLAST searching
# and for loading into GFF DB.
# Should be a role, but this is expedient for now.
sub dump_elegans_ests {
    my $self = shift;
    my $release    = $self->release;
    $self->log->info("  begin: dumping ESTs for C. elegans $release");

    use Ace;
    $|++;
    
    my $acedb_root = $self->acedb_root;

    # connect to database
    my $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
#    my $db = Ace->connect(-path => "$acedb_root/wormbase_$release") || $self->log->logdie("dumping ESTs failed: couldn't open database");
    my $debug_counter;


    my $query = <<END;
find cDNA_Sequence ; >DNA    
END
;
    
#my @seqs = $db->fetch(-query=>qq{find cDNA_Sequence; dna; query find 
#NDB_Sequence; dna"});
#    my @seqs = $db->fetch(-query=>$query);
    my $i = $db->fetch_many(-query=>$query);
    my $file = join("/",$self->ftp_releases_dir,$release,'species','c_elegans','c_elegans.' . $self->release . ".ests.fa.gz");

    return if $self->check_output_file($file);
    open OUT," | gzip -c > $file" or $self->log->logdie("Couldn't open $file for generating the EST file dump");
    
#    foreach (@seqs) {
    while (my $obj = $i->next) {
	$debug_counter++;
	if ($debug_counter % 10000 == 0) {
	    $self->log->info("$debug_counter - [$obj] ...");
	}
    	
	$obj =~ s/\0+\Z//; # get rid of nulls in data stream!
	$obj =~ s!^//.*!!gm;
	my $dna = $obj->asDNA();
	print OUT $dna if $dna;
    }
    close OUT;
    $self->log->info("  end: dumping ESTs for C. elegans");
}



has 'connect_to_ftp' => (
    is         => 'ro',
    lazy_build => 1,
    );

sub _build_connect_to_ftp {
    my $self = shift;

    my $contact_email = $self->contact_email;
    my $ftp_server    = $self->remote_ftp_server;

    my $ftp = Net::FTP::Recursive->new($ftp_server,
				       Debug => 0,
				       Passive => 1) or $self->log->logdie("can't instantiate Net::FTP object");

    $ftp->login('anonymous', $contact_email) or $self->log->logdie("cannot login to remote FTP server: $!");
    $ftp->binary()                           or $self->log->error("couldn't switch to binary mode for FTP");    
    return $ftp;
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
