package WormBase::Update::Staging::PrecacheContent;

use local::lib '/usr/local/wormbase/website/tharris/extlib';
use Moose;
use Ace;
use WWW::Mechanize;
use Config::JFDI;
use URI::Escape;
use Data::Dumper;
use HTTP::Request;
use WormBase::CouchDB;
use LWP::Simple;
use Parallel::ForkManager;
#use LWP::Parallel::UserAgent;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'precache computationally intensive content of the WormBase site',
);

has 'couchdb' => (
    is         => 'rw',
    lazy_build => 1);

sub _build_couchdb {
    my $self = shift;
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release });
    return $couchdb;
}


sub run {
    my $self = shift;       
    my $release = $self->release;
    # $self->precache_content();
#    $self->precache_to_couchdb();
    $self->precache_to_couchdb_parallel();


#    foreach my $class (qw/gene variation protein gene_class/) {
    foreach my $class (qw/gene variation protein gene_class/) {
	$self->precache_classic_content($class);
    }
}


# Precache specific WormBase widgets.
# Reads the application configuration file and looks for widgets
# with the "precache" flag set.

# For each of these, a REST request for HTML will be sent.

# The web app will cache data structures at:
# /usr/local/wormbase/shared/cache.

# Returned HTML will be stored at:
# /usr/local/wormbase/databases/cache/VERSION


sub precache_content {
    my $self = shift;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/staging/wormbase.conf');
    my $config = $c->get;

    my $base_url = $self->precache_host . '/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
    	       
    # Turn off autocheck so that server errors don't kill us.
    #-agent     => 'WormBase-PreCacher/1.0',
    my $mech = WWW::Mechanize->new(
				   -agent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.2 (KHTML, like Gecko) Ubuntu/11.04 Chromium/15.0.871.0 Chrome/15.0.871.0 Safari/535.2',
				   -autocheck => 0 );
    
    # Set the stack depth to 0: no need to retain history;
    $mech->stack_depth(0);
    
#    print Dumper($config);
    foreach my $class (sort keys %{$config->{sections}->{species}}) {
	next if $class eq 'title'; # Kludge.

	# Horribly broken classes, currently uncacheable.
	next if $class eq 'anatomy_term';
	next unless $class eq 'gene';

	foreach my $widget (keys %{$config->{sections}->{species}->{$class}->{widgets}}) {
	    next unless $widget eq 'overview';
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;

#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {
		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");
		
		my $cache_log = join("/",$cache_root,'logs',"$version-$class-$widget.txt");
		my %previous = $self->_parse_cached_widgets_log($cache_log); 

		# Open cache log for writing.
		open OUT,">>$cache_log";

		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();

		my %status;
		
		# Assume that classes in the config file match AceDB classes.
		my $ace_class = ucfirst($class);
		my $i = $db->fetch_many($ace_class => '*');
		while (my $obj = $i->next) {

		    if ($previous{$obj}) {
			print STDERR "Already seen $class $obj. Skipping...";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
			next;
		    }
		    
		    print STDERR "Fetching and caching $class:$widget:$obj";
		    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    
		    my $cache_start = time();
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');

		    my $url = sprintf($base_url,$class,$obj,$widget);
		    eval { $mech->get($url) };
		    my $success = ($mech->success) ? 'success' : 'failed';
		    my $cache_stop = time();
		    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    $status{$class}++;
		 
		    if ($mech->success) {
			$mech->save_content("$cache/$obj.html");
		    } else {
			print ERROR join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    }		    	
		}
		my $end = time();
		my $seconds = $end - $start;
		print OUT "\n\nTime required to cache " . (scalar keys %status) . ": ";
		printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
		close OUT;
	    }
	}	
    }
}


# Request objects serially.  The precache_host will handle stashing them
# into couchdb.

sub precache_to_couchdb {
    my $self = shift;

    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/staging/wormbase.conf');
    my $config = $c->get;

    my $base_url = $self->precache_host . '/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
           
    # Turn off autocheck so that server errors don't kill us.
    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
				   -autocheck => 0 );
    
    # Set the stack depth to 0: no need to retain history;
    $mech->stack_depth(0);
    
#    print Dumper($config);
    foreach my $class (sort keys %{$config->{sections}->{species}}) {
	next if $class eq 'title'; # Kludge.
	
	# Horribly broken classes, currently uncacheable.
	# next if $class eq 'anatomy_term';

	next unless $class eq 'gene';

	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	foreach my $widget (keys %{$config->{sections}->{species}->{$class}->{widgets}}) {
#	    next unless $widget eq 'external_links';
#	    next unless $widget eq 'homology';
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;
	    $precache = 1 if $class_level_precache;
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {
		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");

		my $cache_log = join("/",$cache_root,'logs',"$version-$class-$widget.txt");

		# 1. To find out what we've already cached, just use our cache log and an offset to fetch()
		my %previous = $self->_parse_cached_widgets_log($cache_log); 
		next if defined $previous{COMPLETE};
		my $count = scalar keys %previous;
		$count ||= 0;

		# Open cache log for writing.
		open OUT,">>$cache_log";

		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();

		my %status;
		
		# Assume that classes in the config file match AceDB classes, which might not be true.
		my $ace_class = ucfirst($class);
#		my $i = $db->fetch_many($ace_class => '*');
#		while (my $obj = $i->next) {
		my @objects = $db->fetch(-class => $ace_class,
				   -name  => '*',
				   -offset => $count,
				   -fill   => undef,
		    );

		foreach my $obj (@objects) {
		    # We're already selecting objects from a given offset,
		    # assuming that those who have come before are already cached.
		    # The code below checks for the presence of the document in couch.
		    # Also: in the future we might want to selectively REPLACE documents.
#		    if ($self->check_if_stashed_in_couchdb($class,$widget,$obj)) {
#			print STDERR " --> $class:$widget:$obj ALREADY CACHED; SKIPPING\n";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
#			next;
#		    }
		    
		    print STDERR "Fetching and caching $class:$widget:$obj";
		    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    
		    my $cache_start = time();
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');

		    my $url = sprintf($base_url,$class,$obj,$widget);
		    eval { $mech->get($url) };
		    my $success = ($mech->success) ? 'success' : 'failed';
		    my $cache_stop = time();
		    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    $status{$class}++;
		 
		    if ($mech->success) {
			# Not necessary to save to couch.  This is handled by the app.
			# my $response = $self->save_to_couchdb($class,$widget,$obj,$mech->content);
		    } else {
			print ERROR join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    }		    	
		}
		my $end = time();
		my $seconds = $end - $start;
		print OUT "=\n";
		print OUT "Time required to cache " . (scalar keys %status) . ": ";
		printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
		print OUT "COMPLETE";
		close OUT;
	    }
	}	
    }
}


# Request objects serially.  The precache_host will handle stashing them
# into couchdb.

sub precache_to_couchdb_by_class {
    my $self = shift;

    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/staging/wormbase.conf');
    my $config = $c->get;

    my $base_url = $self->precache_host . '/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
           
    # Turn off autocheck so that server errors don't kill us.
    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
				   -autocheck => 0 );
    
    # Set the stack depth to 0: no need to retain history;
    $mech->stack_depth(0);
    
#    print Dumper($config);
    foreach my $class (sort keys %{$config->{sections}->{species}}) {
	next if $class eq 'title'; # Kludge.
	
	# Horribly broken classes, currently uncacheable.
	next if $class eq 'anatomy_term';
	next unless $class eq 'gene';

	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	foreach my $widget (keys %{$config->{sections}->{species}->{$class}->{widgets}}) {
#	    next unless $widget eq 'external_links';
#	    next unless $widget eq 'homology';
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;
	    $precache = 1 if $class_level_precache;
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {
		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");

		my $cache_log = join("/",$cache_root,'logs',"$version-$class-$widget.txt");

		# 1. To find out what we've already cached, just use our cache log and an offset to fetch()
		my %previous = $self->_parse_cached_widgets_log($cache_log); 
		next if defined $previous{COMPLETE};
		my $count = scalar keys %previous;
		$count ||= 0;

		# Open cache log for writing.
		open OUT,">>$cache_log";

		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();

		my %status;
		
		# Assume that classes in the config file match AceDB classes, which might not be true.
		my $ace_class = ucfirst($class);
#		my $i = $db->fetch_many($ace_class => '*');
#		while (my $obj = $i->next) {
		my @objects = $db->fetch(-class => $ace_class,
				   -name  => '*',
				   -offset => $count,
				   -fill   => undef,
		    );

		foreach my $obj (@objects) {
		    # We're already selecting objects from a given offset,
		    # assuming that those who have come before are already cached.
		    # The code below checks for the presence of the document in couch.
		    # Also: in the future we might want to selectively REPLACE documents.
#		    if ($self->check_if_stashed_in_couchdb($class,$widget,$obj)) {
#			print STDERR " --> $class:$widget:$obj ALREADY CACHED; SKIPPING\n";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
#			next;
#		    }
		    
		    print STDERR "Fetching and caching $class:$widget:$obj";
		    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    
		    my $cache_start = time();
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');

		    my $url = sprintf($base_url,$class,$obj,$widget);
		    eval { $mech->get($url) };
		    my $success = ($mech->success) ? 'success' : 'failed';
		    my $cache_stop = time();
		    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    $status{$class}++;
		 
		    if ($mech->success) {
			# Not necessary to save to couch.  This is handled by the app.
			# my $response = $self->save_to_couchdb($class,$widget,$obj,$mech->content);
		    } else {
			print ERROR join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    }		    	
		}
		my $end = time();
		my $seconds = $end - $start;
		print OUT "=\n";
		print OUT "Time required to cache " . (scalar keys %status) . ": ";
		printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
		print OUT "COMPLETE";
		close OUT;
	    }
	}	
    }
}




sub precache_to_couchdb_parallel {
    my $self = shift;
    
    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/staging/wormbase.conf');
    my $config = $c->get;

    my $base_url = $self->precache_host . '/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
           
#    # Turn off autocheck so that server errors don't kill us.
#    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
#				   -autocheck => 0 );
#    
#    # Set the stack depth to 0: no need to retain history;
#    $mech->stack_depth(0);
    
#    print Dumper($config);
    foreach my $class (sort keys %{$config->{sections}->{species}}) {
	next if $class eq 'title'; # Kludge.
	
	# Horribly broken classes, currently uncacheable.
	# next if $class eq 'anatomy_term';

	next unless $class eq 'gene';

	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	foreach my $widget (sort keys %{$config->{sections}->{species}->{$class}->{widgets}}) {
	    # References and human diseases are actually searches and not cached by the app.
	    next if $widget eq 'references';
	    next if $widget eq 'human_diseases';

	    # These two are broken at the moment.
	    next if $widget eq 'interactions';
	    next if $widget eq 'phenotype';
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;
	    $precache = 1 if $class_level_precache;
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {
		# Create a list of URIs.
		my @uris;

		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");

		my $cache_log = join("/",$cache_root,'logs',"$version-$class-$widget.txt");

		# 1. To find out what we've already cached, just use our cache log and an offset to fetch()
		$self->log->info("Precaching $class:$widget at $base_url");
		my %previous = $self->_parse_cached_widgets_log($cache_log);
		next if defined $previous{COMPLETE};
		my $count = scalar keys %previous;
		$count ||= 0;

		# Open cache log for writing.
		open OUT,">>$cache_log";

		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();

		my %status;
		
		# Assume that classes in the config file match AceDB classes, which might not be true.
		my $ace_class = ucfirst($class);
#		my $i = $db->fetch_many($ace_class => '*');
#		while (my $obj = $i->next) {
		my @objects = $db->fetch(-class => $ace_class,
				   -name  => '*',
				   -offset => $count,
				   -fill   => undef,
		    );

		foreach my $obj (@objects) {
#		    if (eval { $obj->Species } ) {
#			next unless $obj->Species =~ /elegans/;
#		    }
		    # We're already selecting objects from a given offset,
		    # assuming that those who have come before are already cached.
		    # The code below checks for the presence of the document in couch.
		    # Also: in the future we might want to selectively REPLACE documents.
#		    if ($self->check_if_stashed_in_couchdb($class,$widget,$obj)) {
#			print STDERR " --> $class:$widget:$obj ALREADY CACHED; SKIPPING\n";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
#			next;
#		    }
		    
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');
		    
		    my $url = sprintf($base_url,$class,$obj,$widget);
		    push @uris,$url;
		}
		
		# Max 5 processes for parallel download
		my $pm = new Parallel::ForkManager(8); 

		my $uris_seen = 0;		
		my $total_uris = scalar @uris;
		foreach my $uri (@uris) {
		    my ($protocol,$nothing,$host,$rest,$widget_path,$class,$object,$widget) = split("/",$uri);
#		    die join('---',$protocol,$nothing,$host,$rest,$widget_path,$class,$object,$widget),"\n";

		    $uris_seen++;
		    if ($uris_seen % 100 == 0) {
			my $remaining = $total_uris - $uris_seen;
			print STDERR "   cached $uris_seen out of $total_uris ; $remaining remaining ; last was $uri";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    }
		    
		    my $cache_start = time();
		    $pm->start and next; # do the fork
		    my $cache_stop = time();
		    		       
		    my $content = get($uri) or
			print ERROR join("\t",$class,$object,$widget,$uri,'failed',$cache_stop - $cache_start),"\n";

		    if ($content) {
			my $cache_stop = time();
			print OUT join("\t",$class,$object,$widget,$uri,'success',$cache_stop - $cache_start),"\n";
			$status{$class}++;
		    }
		    
		    $pm->finish; # do the exit in the child process
		}
		$pm->wait_all_children;
	    
		my $end = time();
		my $seconds = $end - $start;
		print OUT "=\n";
		print OUT "Time required to cache " . (scalar keys %status) . ": ";
		printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
		print OUT "COMPLETE";
		close OUT;
	    }
	}	
    }
}







=pod

sub precache_to_couchdb_parallel {
    my $self = shift;

    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/staging/wormbase.conf');
    my $config = $c->get;

    my $base_url = $self->precache_host . '/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
    
    my $ua = LWP::Parallel::UserAgent->new();
    
    # Turn off autocheck so that server errors don't kill us.
    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
				   -autocheck => 0 );
    
    # Set the stack depth to 0: no need to retain history;
    $mech->stack_depth(0);
    
#    print Dumper($config);
    foreach my $class (sort keys %{$config->{sections}->{species}}) {
       	
	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;
	
	# Horribly broken classes, currently uncacheable.	
	next unless $class eq 'gene';
	
	foreach my $widget (keys %{$config->{sections}->{species}->{$class}->{widgets}}) {	    
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;
	    $precache = 1 if $class_level_precache;
	    
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {		
		my @urls;

		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");
		
		my $cache_log = join("/",$cache_root,'logs',"$version-$class-$widget.txt");
		
		# 1. To find out what we've already cached, just use our cache log and an offset to fetch()
		my %previous = $self->_parse_cached_widgets_log($cache_log); 
		next if defined $previous{COMPLETE};
		my $count = scalar keys %previous;
		$count ||= 0;

		# Set up my parallel user agent
		my $pua = LWP::Parallel::UserAgent->new();
		$pua->in_order  (1);  # handle requests in order of registration
		$pua->duplicates(0);  # ignore duplicates
		$pua->timeout   (30); # in seconds
		$pua->max_req   (5);  # sets maximum number of parallel requests per host
#		$pua->redirect  (1);  # follow redirects
		
		# Open cache log for writing.
		open OUT,">>$cache_log";
		
		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();
		
		my %status;
		
		# Assume that classes in the config file match AceDB classes, which might not be true.
		my $ace_class = ucfirst($class);
#		my $i = $db->fetch_many($ace_class => '*');
#		while (my $obj = $i->next) {
		my @objects = $db->fetch(-class => $ace_class,
					 -name  => '*',
					 -offset => $count,
					 -fill   => undef,
		    );
		
		foreach my $obj (@objects) {
		    # We're already selecting objects from a given offset,
		    # assuming that those who have come before are already cached.
		    # The code below checks for the presence of the document in couch.
		    # Also: in the future we might want to selectively REPLACE documents.
#		    if ($self->check_if_stashed_in_couchdb($class,$widget,$obj)) {
#			print STDERR " --> $class:$widget:$obj ALREADY CACHED; SKIPPING\n";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
#			next;
#		    }
		    
		    print STDERR "Fetching and caching $class:$widget:$obj";
		    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    
		    my $cache_start = time();
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');
		    
		    my $url = sprintf($base_url,$class,$obj,$widget);
		    
		    push @urls,HTTP::Request->new('GET',$url);
		}
		
		foreach my $req (@urls) {
		    print "Registering '". $req->url . "'\n";
		    if ( my $res = $pua->register($req) ) { 
			print STDERR $res->error_as_HTML; 
		    }  
		}
		# Wait for all requests to return.
		my $entries = $pua->wait();
		
		foreach (keys %$entries) {
		    my $res = $entries->{$_}->response;
		    
		    print "Answer for '",$res->request->url, "' was \t", $res->code,": ",
		    $res->message,"\n";
		}
	    }

#	    eval { $mech->get($url) };
#	    my $success = ($mech->success) ? 'success' : 'failed';
#	    my $cache_stop = time();
#	    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
#	    $status{$class}++;
#	    
#	    if ($mech->success) {
#		my $response = $self->save_to_couchdb($class,$widget,$obj,$mech->content);
#	    } else {
#		print ERROR join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
#	    }
	    my $end = time();
	    my $seconds = $end - $start;
	    print OUT "=\n";
	    print OUT "\n\nTime required to cache " . (scalar keys %status) . ": ";
	    printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
	    print OUT "COMPLETE";
	    close OUT;
	}
    }
}	

=cut


# Has this entity already been stashed in couchdb?
sub check_if_stashed_in_couchdb {
    my ($self,$class,$widget,$name) = @_;
    
    my $couch = $self->couchdb;
    my $uuid  = join("_",$class,$widget,$name);
    my $data  = $couch->check_for_document($uuid);
    return $data ? 1 : 0;
}

sub save_to_couchdb {
    my ($self,$class,$widget,$name,$content) = @_;    
    my $couch = $self->couchdb;
    my $uuid  = join("_",$class,$widget,$name);
    my $response = $couch->create_document({attachment => $content,
					    uuid       => $uuid,			     
					   });
    return $response;
}




sub precache_classic_content {
    my ($self,$class) = @_;
    my $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
    
    my $base_url = $self->precache_classic_site_host;

    $|++;
    
    my %class2url = ( gene      => $base_url . 'db/gene/gene?class=Gene;name=',
		      variation => $base_url . 'db/gene/variation?class=Variation;name=',
		      protein   => $base_url . 'db/seq/protein?class=Protein;name=',);
    
    my $version = $db->status->{database}{version};
    my $cache = join("/",$self->support_databases_dir,$version,'cache',$class);
    system("mkdir -p $cache");
    
    my $start = time();    
    
    my %previous = _parse_cache_log($cache,$version); 
    
    open OUT,">>$cache/$version-precached-pages.txt";
    
    my %status;
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans"});
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans" AND CGC_name AND Molecular_name});

#    my $query_class = ucfirst($class);
#my $i     = $db->fetch_many(-query=>qq{find $query_class Species="Caenorhabditis elegans"});

    my $i = $db->fetch_many(ucfirst($class),'*');
    while (my $obj = $i->next) {
	next if $class eq 'protein' && $obj->name != /^WP:/;
	next unless $obj->Species eq 'Caenorhabditis elegans';
		
	if ($previous{$obj}) {
	    print STDERR "Already seen $class $obj. Skipping...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	    next;
	}
	
	print STDERR "Fetching and caching $obj";
	print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	my $url = $class2url{$class} . $obj;
	
	my $cache_start = time();
	# No need to watch state - create a new agent for each gene to keep memory usage low.
	my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
	$mech->get($url);
	my $success = ($mech->success) ? 'success' : 'failed';
	my $cache_stop = time();
	$status{$obj} = $success;
	
	if ($mech->success) {
	    open CACHE,">$cache/$obj.html";
	    print CACHE $mech->content;
	    close CACHE;
	}
	
	print OUT join("\t"
		       ,$obj
		       ,$class eq 'gene' ? $obj->Public_name : ''
		       ,$url
		       ,$success
		       ,$cache_stop - $cache_start)
	    ,"\n";
    }
    
    my $end = time();
    my $seconds = $end - $start;
    print OUT "\n\nTime required to cache " . (scalar keys %status) . "objects: ";
    printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];
}

sub _parse_cache_log {
    my ($cache,$version) = @_;
#    open IN,"$previous";
#    return unless (-e "$cache/$version-precached-pages.txt");
    if (-e "$cache/$version-precached-pages.txt") {
	my %previous;

	# First off, just tail the file to see if we're finished.
	my $complete_flag = `tail -1 $cache/$version-precached-pages.txt`;
	chomp $complete_flag;
	if ($complete_flag eq 'COMPLETE') {
	    $previous{$complete_flag}++;
	    return %previous;
	}

	open IN,"$cache/$version-precached-pages.txt" or die "$!";

	while (<IN>) {
	    chomp;
	    my ($obj,$name,$url,$status,$cache_stop) = split("\t");
	    $previous{$obj}++ unless $status eq 'failed';
	    print STDERR "Recording $obj as seen...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
	close IN;
	return %previous;
    }
    return undef;
}


sub _parse_cached_widgets_log {
    my ($self,$cache_log) = @_;
    $self->log->info("  ---> parsing log of previously cached widgets");
    my %previous;
    if (-e "$cache_log") {
	# First off, just tail the file to see if we're finished.
	my $complete_flag = `tail -1 $cache_log`;
	chomp $complete_flag;
	if ($complete_flag =~ /COMPLETE/) {
	    $previous{COMPLETE}++;
	    $self->log->info("  ---> all widgets already cached.");
	    return %previous;
	}

	open IN,"$cache_log" or die "$!";

	while (<IN>) {
	    if (/COMPLETE/) {
		$previous{COMPLETE};
		next;
	    }
	    chomp;
	    my ($class,$obj,$name,$url,$status,$cache_stop) = split("\t");
	    $previous{$obj}++ unless $status eq 'failed';
	    print STDERR "   Recording $obj as seen...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
	print STDERR "\n";
	close IN;
    }
    return %previous;
}




1;
