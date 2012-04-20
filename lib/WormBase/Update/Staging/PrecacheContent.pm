package WormBase::Update::Staging::PrecacheContent;

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
    # Discover where our target couchdb is (for the
    # express purpose of creating a couchdb)
    my $couch_host;
    if ($self->cache_query_host eq 'production') {
	$couch_host = $self->couchdb_host_master;
    } else {
	$couch_host = $self->couchdb_host_staging;
    }
    
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release, couchdb_host => $couch_host });
    return $couchdb;
}

# Attributed used to precache a specific widget
has 'class' => (
    is => 'rw',
    );

has 'widget' => (
    is => 'rw',
    );

# Specify which environment to direct queries to: staging or production.
# This lets me run the precaching script at a low-level even after
# a data release.
has 'cache_query_host' => (
    is => 'rw',
    default => 'staging',
    );


sub run {
    my $self = shift;       
    my $release = $self->release;
#    $self->precache_content('bulk_load');

#    $self->dump_object_lists();
    $self->dump_object_lists_via_tace();
    $self->crawl_website();             # Crawls object by object. Slower, but uses less memory.
#    $self->crawl_website_by_class();   # Creates potentially huge arrays for big classes.
#    $self->precache_classic_content();
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
    my $load_type = shift;

    $|++;
    
    # Make sure that our couchdb exists.
    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    $|++;

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/production/wormbase.conf');
    my $config = $c->get;   
    
    my $method = 'cache_query_host_' . $self->cache_query_host;
    my $base_url = $self->$method . '/rest/widget/%s/%s/%s';
    
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

	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	foreach my $widget (sort keys %{$config->{sections}->{species}->{$class}->{widgets}}) {
	    my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
	    $precache ||= 0;
	    $precache = 1 if $class_level_precache;

#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
	    
	    if ($precache) {
		# Create the directory where we (may) store generated HTML.
		my $cache = join("/",$cache_root,$class,$widget);
		system("mkdir -p $cache");
		
		my $cache_log = join("/",$cache_root,'logs',"$class-$widget.txt");

		# 1. To find out what we've already cached, just use our cache log and an offset to fetch()
		# 2. (or check against the actual %previous list)
		my %previous = $self->_parse_cached_widgets_log($cache_log); 
#		next if defined $previous{COMPLETE};
		my $count = scalar keys %previous;
		$count ||= 0;

		# Open cache log for writing.
		open OUT,">>$cache_log";

		# And set up the cache error file
		my $cache_err = join("/",$cache_root,'logs',"00-errors.txt");
		open ERROR,">>$cache_err";
		
	    	my $start = time();

		my %status;
		
		# Assume that classes in the config file match AceDB classes.
		my $ace_class = ucfirst($class);

		# Via offset
		if (0) {
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
		    }
		}
			
		my $i = $db->fetch_many($ace_class => '*');
		while (my $obj = $i->next) {

#		    if ($previous{$obj}) {
		    if ($previous{"$class$obj$widget"}) {
			print STDERR "Already seen $class $obj. Skipping...";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
			next;
		    }
		    		    
		    my $cache_start = time();
		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');

		    my $url = sprintf($base_url,$class,$obj,$widget);

		    if ($status{$class} % 100 == 0) {
			print STDERR "   cached $status{$class} ; last was $url";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    }
		    
		    eval { $mech->get($url) };
		    my $success = ($mech->success) ? 'success' : 'failed';
		    my $cache_stop = time();
		    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		    $status{$class}++;
		    
		    if ($mech->success) {
			if ($load_type eq 'bulk_load') {
			    #    1. save it to the filesystem and do a bulk insert (disable caching in the app)
			    $mech->save_content("$cache/" . $class . '_' . $widget . '_' . "$obj.html");
			} else {
			    #    2. let the app cache it
			    #   (nothing to do for this case)
			}
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

	# Bulk load to couchdb.
	if ($load_type eq 'bulk_load') {
	    #
	}
    }
}



sub crawl_website {
    my $self = shift;

    $|++;
    
    # Create a database corresponding to the current release,
    # silently failing if it already exists.
#    my $couch = $self->couchdb;
#    $couch->create_database;

    my $method = 'cache_query_host_' . $self->cache_query_host;
    my $base_url = $self->$method . '/rest/widget/%s/%s/%s';

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/production/wormbase.conf');
    my $config = $c->get;

    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");

    my $master_log_file = join("/",$self->support_databases_dir,$version,'cache','logs',"00-master_log.txt");
    open MASTER,">>$master_log_file";
           
#    # Turn off autocheck so that server errors don't kill us.
#    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
#				   -autocheck => 0 );
#    
#    # Set the stack depth to 0: no need to retain history;
#    $mech->stack_depth(0);
    
#    print Dumper($config);
    my @classes;
    if ($self->class) {
	push @classes,$self->class;
    } else {
	@classes = sort keys %{$config->{sections}->{species}};
    }
    
    foreach my $class (@classes) {
	next if $class eq 'title'; # Kludge.
	
	# Horribly broken classes, currently uncacheable.
	# next if $class eq 'anatomy_term';
#	next if $class eq 'cds';
#	next unless $class eq 'variation';

        # Class-level status and timers.
	my $start = time();
	my %status;
		
	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	my $cache = join("/",$cache_root,$class);
	system("mkdir -p $cache");
		    
	my $cache_log = join("/",$cache_root,'logs',"$class.txt");
	
	$self->log->info("Precaching widgets for the $class class");
	my %previous = $self->_parse_cached_classes_log($cache_log);
#	next if defined $previous{COMPLETE};   # eg this class is finished.


	# And set up the cache error file
	my $cache_err = join("/",$cache_root,'logs',"00-errors.txt");
	open ERROR,">>$cache_err";

	my $object_list = join("/",$cache_root,'logs',"$class-object_list.txt");
	open OBJECTS,$object_list or $self->log->logdie("Could not open the object list file: $object_list");

	# Open cache log for writing.
	open OUT,">>$cache_log";


	# Which widgets will we be caching?
	my @widgets;
	if ($self->widget) {
	    push @widgets,$self->widget;
	} else {
	    @widgets = sort keys %{$config->{sections}->{species}->{$class}->{widgets}};
	}
	
	while (my $obj = <OBJECTS>) {
	    chomp $obj;
	    my @uris;  # All uris for a single object, fetched in parallel.
	    
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

	    # Keep track of the number of objects we have seen.
	    $status{$class}{objects}++;
	    	    
	    foreach my $widget (@widgets) {
		# References and human diseases are actually searches and not cached by the app.
		next if $widget eq 'references';
#		next if $widget eq 'human_diseases';
		# These two are broken at the moment.
#		next if $widget eq 'interactions';
#		next if $widget eq 'phenotype';
#		next if $widget eq 'sequences';
#		next if $widget eq 'location';

		my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
		$precache ||= 0;
		$precache = 1 if $class_level_precache;
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";

		if ($precache) {
		    my $url = sprintf($base_url,$class,$obj,$widget);
#		    if ($previous{$url}) {	       
		    if ($previous{"$class$obj$widget"}) {
#			print STDERR "Already requested $url. Skipping...";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
			next;
		    }
		    push @uris,$url;
		}
	    }
	    
            # Max 5 processes for parallel download
	    my $pm = new Parallel::ForkManager(6); 
	    foreach my $uri (@uris) {	       		
		$status{$class}{uris}++;
		my ($protocol,$nothing,$host,$rest,$widget_path,$class,$object,$widget) = split("/",$uri);
		
		my $cache_start = time();
		$pm->start and next; # do the fork
		my $cache_stop = time();
		
		my $content = get($uri) or
		    print ERROR join("\t",$class,$object,$widget,$uri,'failed',$cache_stop - $cache_start),"\n";
		
		if ($content) {
		    my $cache_stop = time();
		    print OUT join("\t",$class,$object,$widget,$uri,'success',$cache_stop - $cache_start),"\n";
		}
		    
		$pm->finish; # do the exit in the child process
	    }
	    $pm->wait_all_children;
	 
	    if ($status{$class}{objects} % 10 == 0) {
		print STDERR "   cached $status{$class}{objects} $class objects and $status{$class}{uris} uris; last was $obj";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
	    }   
	}
	my $end = time();
	my $seconds = $end - $start;
	print MASTER "=\n";
	print MASTER "CLASS: $class\n";
	print MASTER "Time required to cache " . $status{$class}{objects} . ' objects comprising ' . $status{$class}{uris} . 'uris: ';
	printf MASTER "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
	print MASTER "\n\n";
	close OUT;
    }
}	





sub crawl_website_by_class {
    my $self = shift;

    $|++;
    
    # Create a database corresponding to the current release,
    # silently failing if it already exists.
#    my $couch = $self->couchdb;
#    $couch->create_database;

    # Where should we send queries?
    my $method = 'cache_query_host_' . $self->cache_query_host;
    my $base_url = $self->$method . '/rest/widget/%s/%s/%s';

    my $c = Config::JFDI->new(file => '/usr/local/wormbase/website/production/wormbase.conf');
    my $config = $c->get;

    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $self->release;
#    my $version = $db->status->{database}{version};
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");
           
#    # Turn off autocheck so that server errors don't kill us.
#    my $mech = WWW::Mechanize->new(-agent     => 'WormBase-PreCacher/1.0',
#				   -autocheck => 0 );
#    
#    # Set the stack depth to 0: no need to retain history;
#    $mech->stack_depth(0);
    
#    print Dumper($config);
    my @classes;
    if ($self->class) {
	push @classes,$self->class;
    } else {
	@classes = sort keys %{$config->{sections}->{species}};
    }

    my $master_log_file = join("/",$self->support_databases_dir,$version,'cache','logs',"00-master_log.txt");
    open MASTER,">>$master_log_file";
    
    foreach my $class (@classes) {
	next if $class eq 'title'; # Kludge.
	
	# Horribly broken classes, currently uncacheable.
	# next if $class eq 'anatomy_term';

	next unless $class eq 'protein';

        # Class-level status and timers.
	my $start = time();
	my %status;
		
	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; } || 0;

	my $cache = join("/",$cache_root,$class);
	system("mkdir -p $cache");
		    
	my $cache_log = join("/",$cache_root,'logs',"$class.txt");
	
	$self->log->info("Precaching widgets for the $class class");
	my %previous = $self->_parse_cached_classes_log($cache_log);
	next if defined $previous{COMPLETE};   # eg this class is finished.

	# Open cache log for writing.
	open OUT,">>$cache_log";

	# And set up the cache error file
	my $cache_err = join("/",$cache_root,'logs',"00-errors.txt");
	open ERROR,">>$cache_err";

	# Assume that classes in the config file match AceDB classes, which might not be true.
	my $ace_class = ucfirst($class);
	# Acedb is crapping out while using iterator?
#	my $i = $db->fetch_many($ace_class => '*');
#	while (my $obj = $i->next) {	
	my @objects = map { $_->name } $db->fetch($ace_class => '*');

	my @widgets;
	if ($self->widget) {
	    push @widgets,$self->widget;
	} else {
	    @widgets = sort keys %{$config->{sections}->{species}->{$class}->{widgets}};
	}
	
	my @uris;  # All uris for a class, fetched in parallel.
	foreach my $obj (@objects) {

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
	    
	    foreach my $widget (@widgets) {
		# References and human diseases are actually searches and not cached by the app.
		next if $widget eq 'references';
		next if $widget eq 'human_diseases';

		my $precache = eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; };
		$precache ||= 0;
		$precache = 1 if $class_level_precache;
#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";

		if ($precache) {
		    my $url = sprintf($base_url,$class,$obj,$widget);
#		    if ($previous{$url}) {	       
		    if ($previous{"$class$obj$widget"}) {
#			print STDERR "Already requested $url. Skipping...";
#			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
			next;
		    }
		    push @uris,$url;
		}
	    }
	}

	# Max 5 processes for parallel download
	my $pm = new Parallel::ForkManager(6); 
	foreach my $uri (@uris) {	       		
	    $status{$class}{uris}++;
	    my ($protocol,$nothing,$host,$rest,$widget_path,$class,$object,$widget) = split("/",$uri);

	    # Keep track of the number of objects we have seen.
	    $status{$class}{objects}++;
	    
	    my $cache_start = time();
	    $pm->start and next; # do the fork
	    my $cache_stop = time();
	    
	    my $content = get($uri) or
		print ERROR join("\t",$class,$object,$widget,$uri,'failed',$cache_stop - $cache_start),"\n";
	    
	    if ($content) {
		my $cache_stop = time();
		print OUT join("\t",$class,$object,$widget,$uri,'success',$cache_stop - $cache_start),"\n";
	    }

	    if ($status{$class}{objects} % 10 == 0) {
		print STDERR "   cached $status{$class}{objects} $class objects and $status{$class}{uris} uris; last was $object";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
	    }   
	    
	    $pm->finish; # do the exit in the child process
	}
	$pm->wait_all_children;       

	my $end = time();
	my $seconds = $end - $start;
	print MASTER "=\n";
	print MASTER "CLASS: $class\n";
	print MASTER "Time required to cache " . $status{$class}{objects} . ' objects comprising ' . $status{$class}{uris} . 'uris: ';
	printf MASTER "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
	print MASTER "\n\n";
	close OUT;
    }
}	







sub dump_object_lists {
    my $self = shift;

    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");

    my @classes = $db->classes;

    # PCR_product
    # Oligo_set
    # Homol_data
    # Oligo
    # Feature
    # SAGE_tag
    # Feature_data
    my %acceptable_classes = map { $_ => 1 } qw/ 
                           Sequence
                            Protein
                              Paper
                               Gene
                              Clone
                              Motif
                     Homology_group
                             Person
                      Rearrangement
                          Variation
                          Transgene
                         Gene_class
                         Laboratory
                             Strain
                         Life_stage
                            GO_term
                             Operon
                                CDS
                         Transcript
                         Pseudogene
               Transcription_factor
                               RNAi
                       Expr_pattern
                    Gene_regulation
                 Expression_cluster
                           Antibody
                                 YH
                        Interaction
                    Position_Matrix
                           Molecule
                          Phenotype
                           Analysis
                       Anatomy_term
                         Transposon
/;
    
    foreach my $class (@classes) {
	$self->log->info("dumping the object list for $class...");
	next unless ($acceptable_classes{$class});
	
	my $lower = lc($class);
	my $object_list = join("/",$cache_root,'logs',"$lower-object_list.txt");
	next if (-e $object_list);
	open OUT,">$object_list";
	
	# Acedb is crapping out while using iterator?
	my $i = $db->fetch_many($class => '*');
	while (my $obj = $i->next) {	
#	my @objects = map { $_->name } $db->fetch($ace_class => '*');
	    print OUT $obj->name . "\n";
	}
	close OUT;
    }
}

sub dump_object_lists_via_tace {
    my $self = shift;
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache','logs');
    system("mkdir -p $cache_root");
    open OUT,">$cache_root/00-class_dump_script.ace";
    print OUT <<END;
//tace script to dump database
Find Analysis
list -f $cache_root/analysis.ace
Find Anatomy_term
list -f $cache_root/anatomy_term.ace
Find Antibody
list -f $cache_root/antibody.ace
Find CDS
list -f $cache_root/cds.ace
Find Clone
list -f $cache_root/clone.ace
Find Expr_pattern
list -f $cache_root/expr_pattern.ace
Find Expr_profile
list -f $cache_root/expr_profile.ace
Find Expression_cluster
list -f $cache_root/expression_cluster.ace
Find Feature
list -f $cache_root/feature.ace
Find Gene
list -f $cache_root/gene.ace
Find Gene_class
list -f $cache_root/gene_class.ace
Find Gene_cluster
list -f $cache_root/gene_cluster.ace
Find Gene_regulation
list -f $cache_root/gene_regulation.ace
Find GO_code
list -f $cache_root/go_code.ace
Find GO_term
list -f $cache_root/go_term.ace
Find Homology_group
list -f $cache_root/homology_group.ace
Find Interaction
list -f $cache_root/interaction.ace
Find Laboratory
list -f $cache_root/laboratory.ace
Find Life_stage
list -f $cache_root/life_stage.ace
Find LongText
list -f $cache_root/longText.ace
Find Microarray_results
list -f $cache_root/microarray_results.ace
Find Molecule
list -f $cache_root/molecule.ace
Find Motif
list -f $cache_root/motif.ace
Find Oligo
list -f $cache_root/oligo.ace
Find Oligo_set
list -f $cache_root/oligo_set.ace
Find Operon
list -f $cache_root/operon.ace
Find Paper
list -f $cache_root/paper.ace
Find PCR
list -f $cache_root/pcr.ace
Find Person
list -f $cache_root/person.ace
Find Phenotype
list -f $cache_root/phenotype.ace
Find Picture
list -f $cache_root/picture.ace
Find Position_matrix
list -f $cache_root/position_matrix.ace
Find Protein
list -f $cache_root/protein.ace
Find Pseudogene
list -f $cache_root/pseudogene.ace
Find Rearrangement
list -f $cache_root/rearrangement.ace
Find RNAi
list -f $cache_root/rnai.ace
Find Sequence
list -f $cache_root/sequence.ace
Find Strain
list -f $cache_root/strain.ace
Find Structure_data
list -f $cache_root/structure_data.ace
Find Transcript
list -f $cache_root/transcript.ace
Find Transgene
list -f $cache_root/transgene.ace
Find Variation
list -f $cache_root/variation.ace
END
;

    system("/usr/local/wormbase/acedb/bin/tace /usr/local/wormbase/acedb/wormbase < $cache_root/00-class_dump_script.ace");
    die;
}




sub precache_classic_content {
    my ($self) = @_;
    my $base_url = $self->cache_query_host_classic;

    $|++;
    
    my %class2url = ( clone       => $base_url . '/db/seq/clone?class=Clone;name=',
		      interaction => $base_url . '/db/seq/interaction?class=Interaction;name=',
		      pcr_product => $base_url . '/db/seq/pcr?class=PCR;name=',
		      protein     => $base_url . '/db/seq/protein?class=Protein;name=',	
		      rnai        => $base_url . '/db/seq/rnai?class=RNAi;name=',
		      sage_tag    => $base_url . '/db/seq/sage?class=Sage_tag;name=',
		      sequence    => $base_url . '/db/seq/sequence?class=Sequence;name=',
		      antibody    => $base_url . '/db/gene/antibody?class=Antibody;name=',
		      expr_pattern=> $base_url . '/db/gene/expression?class=Expr_pattern;name=',
		      gene      => $base_url . '/db/gene/gene?class=Gene;name=',
		      gene_class => $base_url . '/db/gene/gene_class?class=Gene_class;name=',
		      gene_regulation => $base_url . '/db/gene/regulation?class=Gene_regulation;name=',
		      strain => $base_url . '/db/gene/strain?class=Strain;name=',
		      structure_data => $base_url . '/db/gene/structure_data?class=Structure_data;name=',
		      variation => $base_url . '/db/gene/variation?class=Variation;name=',
		      laboratory => $base_url . '/db/misc/laboratory?class=Laboratory;name=',
		      life_stage => $base_url . '/db/misc/life_stage?class=Life_stage;name=',
		      person => $base_url . '/db/misc/person?class=Person;name=',
		      phenotype => $base_url . '/db/misc/phenotype?class=Phenotype;name=',
		      gene_ontology => $base_url . '/db/ontology/gene?class=Gene_ontology;name=',
	);

    foreach my $class (qw/clone interaction pcr_product protein rnai sage_tag sequence
                          antibody expr_pattern gene gene_class gene_regulation strain structure_data variation
                          laboratory life_stage paper person phenotype
                           gene_ontology
                          /) {

	my $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
	my $version = $db->status->{database}{version};
	my $cache = join("/",$self->support_databases_dir,$version,'cache',$class);
	system("mkdir -p $cache");
	
	my $start = time();    
        
	my $log_file = join("/",$self->support_databases_dir,$version,'cache','logs',"$class-precached-pages.txt");
	my %previous = _parse_cache_log($log_file); 

        my $master_log_file = join("/",$self->support_databases_dir,$version,'cache','logs',"00-master_log.txt");
        open MASTER,">>$master_log_file";
	
	open OUT,">>$log_file";
		
	my %status;
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans"});
#my $i     = $db->fetch_many(-query=>qq{find Gene Species="Caenorhabditis elegans" AND CGC_name AND Molecular_name});

#    my $query_class = ucfirst($class);
#my $i     = $db->fetch_many(-query=>qq{find $query_class Species="Caenorhabditis elegans"});

    # Assume that classes in the config file match AceDB classes, which might not be true.
	my $ace_class = ucfirst($class);
        $ace_class = 'PCR_product'    if $ace_class eq 'Pcr_product';
	$ace_class = 'RNAi'    if $ace_class eq 'Rnai';
	$ace_class = 'GO_term' if $ace_class eq 'Gene_ontology';
	# Acedb is crapping out while using iterator?
#	my $i = $db->fetch_many($ace_class => '*');
#	while (my $obj = $i->next) {	
	
	my @objects = map { $_->name } $db->fetch($ace_class => '*');
	my @uris;
	foreach my $obj (@objects) {
#	my $i = $db->fetch_many(ucfirst($class),'*');
#    while (my $obj = $i->next) {
#	next if $class eq 'protein' && $obj->name != /^WP:/;
#	next unless $obj->Species eq 'Caenorhabditis elegans';
	    
	    if ($previous{$obj}) {
		print STDERR "Already seen $class $obj. Skipping...";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
		next;
	    }
	    
	    my $url = $class2url{$class} . $obj;
	    push @uris,[$url,$obj];
	}
	
	# Max 5 processes for parallel download
	my $pm = new Parallel::ForkManager(3); 
	foreach my $entry (@uris) {	       		
	    my ($url,$obj) = @$entry;
	    
	    print STDERR "Fetching and caching $class:$obj";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	    
	    my $cache_start = time();
	    $pm->start and next; # do the fork
	    my $cache_stop = time();
	    
	    my $content = get($url);
	    
	    if ($content) {
		open CACHE,">$cache/$obj.html";
		print CACHE $content;
		close CACHE;
		$status{$obj} = 'success';
		
		print OUT join("\t"
			       ,$obj
			       ,$url
			       ,'success'
			       ,$cache_stop - $cache_start)
		    ,"\n";
		
	    } else {
		$status{$obj} = 'failed';
		print OUT join("\t"
			       ,$obj
			       ,$url
			       ,'failed'
			       ,$cache_stop - $cache_start)
		    ,"\n";
	    }
	    
	    $pm->finish; # do the exit in the child process
	}
	$pm->wait_all_children;
	
	# No need to watch state - create a new agent for each gene to keep memory usage low.
#	my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
#	$mech->get($url);
#	my $success = ($mech->success) ? 'success' : 'failed';
#	my $cache_stop = time();
	
	
#	if ($mech->success) {
#	    open CACHE,">$cache/$obj.html";
#	    print CACHE $mech->content;
#	    close CACHE;
#	}
	
	my $end = time();
	my $seconds = $end - $start;
	print MASTER "=\n";
        print MASTER "$class complete!\n";
        print MASTER "\nTime required to cache " . (scalar keys %status) . " objects: ";
        printf MASTER "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];
        print MASTER "\n\n";
    }
}


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
    my $uuid     = join("_",$class,$widget,$name);
    my $response = $couch->create_document({attachment => $content,
					    uuid       => $uuid,			     
					   });
    return $response;
}





sub _parse_cache_log {
    my ($file) = @_;
#    open IN,"$previous";
#    return unless (-e "$cache/$version-precached-pages.txt");

    if (-e "$file") {
	my %previous;

	# First off, just tail the file to see if we're finished.
	my $complete_flag = `tail -1 $file`;
	chomp $complete_flag;
	if ($complete_flag eq 'COMPLETE') {
	    $previous{$complete_flag}++;
	    return %previous;
	}

	open IN,"$file" or die "$!";

	while (<IN>) {
	    chomp;
	    my ($obj,$url,$status,$cache_stop) = split("\t");
	    $previous{$obj}++ unless $status eq 'failed';
	    next if $status eq 'failed';
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
		$previous{COMPLETE}++;
		next;
	    }
	    chomp;
	    my ($class,$obj,$name,$url,$status,$cache_stop) = split("\t");
	    $previous{"$class$obj$name"}++ unless $status eq 'failed';
	    print STDERR "   Recording $obj as seen...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
	print STDERR "\n";
	close IN;
    }
    return %previous;
}



sub _parse_cached_classes_log {
    my ($self,$cache_log) = @_;
    $self->log->info("  ---> parsing log of previously cached classes at $cache_log");
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
		$previous{COMPLETE}++;
		next;
	    }
	    chomp;
	    my ($class,$obj,$name,$url,$status,$cache_stop) = split("\t");
	    $previous{"$class$obj$name"}++ unless $status eq 'failed';
	    print STDERR "   Recording $obj as seen...";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
	}
	print STDERR "\n";
	close IN;
    }
    return %previous;
}



1;
