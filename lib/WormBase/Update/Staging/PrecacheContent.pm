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

    # Discover where our target couchdb is. This is used for 
    #     1. creating a new couchdb
    #     2. bulk operations against the couchdb
    #     3. checking if a URL has already been cached.    
    my $method     = 'couchdb_host_' . $self->couchdb_host;
    my $couch_host = $method =~ 'localhost' ? $method : $self->$method;
    
    my $couchdb = WormBase->create('CouchDB',{ release => $self->release, couchdb_host => $couch_host });
    return $couchdb;
}

# Attribute used to precache a specific widget
has 'class' => (
    is => 'rw',
    );

has 'widget' => (
    is => 'rw',
    );


# Specify which environment to direct queries to: staging or production.
# This lets me run the precaching script at a low-level even after
# a data release.
has 'queries_to' => (
    is      => 'rw',
    default => 'http://staging.wormbase.org/',
    );

has 'couchdb_host' => (
    is      => 'rw',
    default => 'localhost',
    );

has 'already_cached_via' => (
    is      => 'rw',
    default => 'couchdb',
    );


# Where is the caching script running?
#has 'caching_from' => (
#    is => 'rw',
#    default => 'staging',
#    );


sub run {
    my $self = shift;       
    my $release = $self->release;
    $self->dump_object_lists();
#    $self->cache_content_to_disk('bulk_load');
    $self->crawl_website();             # Crawls object by object. Slower, but uses less memory.
#    $self->precache_classic_content();
}


sub dump_object_lists {
    my $self = shift;
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache','logs');
    system("mkdir -p $cache_root");

    return if (-e "$cache_root/dump_complete.txt");

    # Create a tace script of all classes. Much faster for dumping than Ace.pm.
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    my @classes = $db->classes;

    # There are some classes we don't care about. Ignore them.
    my %acceptable_classes = map { $_ => 1 } qw/ 
                           Analysis
                       Anatomy_term
                           Antibody
                        curated_CDS
                              Clone
                 Expression_cluster
                       Expr_pattern
                            Feature
                               Gene
                         Gene_class
                       Gene_cluster
                    Gene_regulation
                            GO_term
                            GO_code
                     Homology_group
                        Interaction
                         Laboratory
                         Life_stage
                Microarrary_results
                           Molecule
                              Motif
                              Oligo
                          Oligo_set
                             Operon
                              Paper
                        PCR_product
                             Person
                          Phenotype
                            Picture
                    Position_Matrix
                            Protein
                         Pseudogene
                      Rearrangement
                               RNAi
                           Sequence
                             Strain
                     Structure_data
                         Transcript
               Transcription_factor
                          Transgene
                         Transposon
                          Variation
                                 YH
/;

    my $release = $self->release;
    open OUT,">$cache_root/00-class_dump_script.ace";
    print OUT "//tace script to dump database for $release\n";

    foreach my $class (@classes) {
	next unless ($acceptable_classes{$class});

	my $file = lc $class;

	# hybrid classes have differnet names in the app.
	if ($class eq 'PCR_product') { $file = 'pcr_oligo' }
	if ($class eq 'curated_CDS') { $file = 'cds'       }
	
	print OUT "Find $class\n";
	print OUT "List -h -f $cache_root/$file.ace\n";
    }
	
    close OUT;

    # Run the newly created tace dump script.
    system("/usr/local/wormbase/acedb/bin/tace /usr/local/wormbase/acedb/wormbase < $cache_root/00-class_dump_script.ace");
    open OUT,">$cache_root/dump_complete.txt";
    print OUT "ACE DUMPING COMPLETE\n";
    close OUT;
}



# Precache specific WormBase widgets.
# Reads the application configuration file and looks for widgets
# with the "precache" flag set.

# For each of these, a REST request for HTML will be sent.

# The web app will cache data structures at:
# /usr/local/wormbase/shared/cache.

# Returned HTML will be stored at:
# /usr/local/wormbase/databases/cache/VERSION

sub crawl_website {
    my $self      = shift;
    my $load_type = shift;

    $|++;
    
    # Create a database corresponding to the current release,
    # silently failing if it already exists.
    my $couch = $self->couchdb;
    $couch->create_database;

    # Where to send requests
    my $base_url = $self->queries_to;

    # Kludge: strip trailing slash: breaks processing below.
    $base_url =~ s/\/$//;

    $base_url .= '/rest/widget/%s/%s/%s';

    # There should be a symlink at:
    # /usr/local/wormbase/wormbase.conf -> /usr/local/wormbase/website/WHATEVER/wormbase.conf
    # (Doing it this way because of NFS mount but may want to use different configs)
    my $local_config = -e '/usr/local/wormbase/wormbase.conf' 
	? '/usr/local/wormbase/wormbase.conf' 
	: '/usr/local/wormbase/website/production/website.conf';
    my $c = Config::JFDI->new(file => $local_config);
    my $config = $c->get;

    my $db      = Ace->connect(-host=>'localhost',-port=>2005) or warn;
    my $version = $self->release;
    my $cache_root = join("/",$self->support_databases_dir,$version,'cache');
    system("mkdir -p $cache_root/logs");

    my $master_log_file = join("/",$cache_root,'logs',"00-master.log");
    open MASTER,">>$master_log_file";

    my $master_error_file= join("/",$cache_root,'logs',"00-master.err");
    open ERROR,">>$master_error_file";
 
    # Using WWW::Mech
    # Turn off autocheck so that server errors don't kill us.
    #    my $mech = WWW::Mechanize->new(
    #	                                -agent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.2 (KHTML, like Gecko) Ubuntu/11.04 Chromium/15.0.871.0 Chrome/15.0.871.0 Safari/535.2',
    #	                                -autocheck => 0 );
    #    
    # Set the stack depth to 0: no need to retain history;
    #    $mech->stack_depth(0);
    
#    print Dumper($config);
    my @classes;
    if ($self->class) {
	push @classes,$self->class;
    } else {
	@classes = sort { $a cmp $b } (keys %{$config->{sections}->{species}}),(keys %{$config->{sections}->{resources}});
    }
    
    foreach my $class (@classes) {
	next if $class eq 'title'; # Kludge.
	
        # Class-level status and timers.
	my $start = time();
	my %status;
		
	# Allow class-level specification of precaching.
	my $class_level_precache = eval { $config->{sections}->{species}->{$class}->{precache}; }
	|| eval { $config->{sections}->{resources}->{$class}->{precache}; }
	|| 0;
		  
	my $cache_log = join("/",$cache_root,'logs',"$class.log");
	
	$self->log->info("Precaching widgets for the $class class");

	my %previous;
	if ($self->already_cached_via eq 'logs') {
	    %previous = $self->_parse_cached_classes_log($cache_log);
	}

	# (Re)open class level cache log for writing.
	open OUT,">>$cache_log";

	# Create a class-level error log.
	my $class_err = join("/",$cache_root,'logs',"$class.err");
	open CLASS_ERROR,">>$class_err";

	# Which widgets will we be caching?
	my @widgets;
	if ($self->widget) {
	    push @widgets,$self->widget;
	} else {
	    @widgets = sort keys %{$config->{sections}->{species}->{$class}->{widgets}};
	    @widgets =  sort keys %{$config->{sections}->{resources}->{$class}->{widgets}} unless @widgets > 0;
	}

	my $object_list = join("/",$cache_root,'logs',"$class.ace");
	open OBJECTS,$object_list or $self->log->logwarn("Could not open the object list file: $object_list");
	
	while (my $obj = <OBJECTS>) {
	    chomp $obj;
	    # Clean up ace files
	    next if $obj =~ /^\w/;
	    next if $obj eq "";
	    $obj =~ s/^\s//;
	    my @uris;  # All uris for a single object, fetched in parallel.
	    
	    # Create a REST request of the following format:
	    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by
	    
	    # api delivers HTML by default.
	    # $mech->add_header("Content-Type" => 'text/html');

	    # Keep track of the number of objects we have seen.
	    $status{$class}{objects}++;
	    	    
	    foreach my $widget (@widgets) {
		# References and human diseases are actually searches and not cached by the app.
		next if $widget eq 'references';
		next if $widget eq 'human_diseases';		

		# Ignore class-level widgets.
		next if $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{display}
		&& $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{display} eq 'index';
		next if $config->{sections}->{resources}->{$class}->{widgets}->{$widget}->{display}
		&& $config->{sections}->{resources}->{$class}->{widgets}->{$widget}->{display} eq 'index';

		# Is the precache flag set for this widget?
		my $precache = defined $config->{sections}->{species}->{$class}
		? eval { $config->{sections}->{species}->{$class}->{widgets}->{$widget}->{precache}; }
		: eval { $config->{sections}->{resources}->{$class}->{widgets}->{$widget}->{precache}; };
		$precache ||= 0;
		$precache = 1 if $class_level_precache;

#	    print join("-",keys %{$config->{sections}->{species}->{$class}->{widgets}->{$widget}}) . "\n";
#	    print join("\t",$class,$widget,$precache) . "\n";
		
		if ($precache) {

		    # Create a REST request of the following format:
		    # curl -H content-type:application/json http://api.wormbase.org/rest/widget/gene/WBGene00006763/cloned_by

		    # api delivers HTML by default.
                    # $mech->add_header("Content-Type" => 'text/html');

		    my $url = sprintf($base_url,$class,$obj,$widget);

		    # Have we already cached this class:obj:widget?
		    # Two options: check either the log file OR check couch itself.
		    my $already_cached;		    

		    # How should we check if we are already cached?		    
		    if ($self->already_cached_via eq 'logs') {
			# Check the cache log to see if we have already been cached.
			# checking the cache log should do similar URL escaping as check_if_stashed...?
			# Although right now, the cache_log only escapes hashes and nothing else.
			if ($previous{"$class$obj$widget"}) {
			    $already_cached++;
			}
		    } elsif ($self->already_cached_via eq 'couchdb') {						
			# The code below checks for the presence of the document in couch.
			# Also: in the future we might want to selectively REPLACE documents.
			if ($self->check_if_stashed_in_couchdb($class,$widget,$obj)) {
			    $already_cached++;
			    print OUT join("\t",$class,$obj,$widget,$url,'success',0,'cached_in_couch'),"\n";
			}
		    } else { }

		    if ($already_cached) {			
			print STDERR " --> $class:$widget:$obj ALREADY CACHED; SKIPPING";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
			$status{$class}{widgets}{$widget}++;
			next;
		    } else {
			print STDERR " --> $class:$widget:$obj NOT CACHED";
			print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
		    }

		    # Remove hashes.  Hashes break our app and couchdb queries.
		    $url =~ s/\#/\%23/g;
		    push @uris,$url;
		}

		# Using WWW::Mech one-by-one AND writing the output to disk.
#		eval { $mech->get($url) };
#		    my $success = ($mech->success) ? 'success' : 'failed';
#		    my $cache_stop = time();
#		    print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
#		    $status{$class}++;
#		    
#		    if ($mech->success) {
#			if ($load_type eq 'bulk_load') {
#			    #    1. save it to the filesystem and do a bulk insert (disable caching in the app)
#			    $mech->save_content("$cache/" . $class . '_' . $widget . '_' . "$obj.html");
#			} else {
#			    #    2. let the app cache it
#			    #   (nothing to do for this case)
#			}
#		    } else {
#			print CLASS_ERROR join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
#		    }
	    }
	    
            # Max 5 processes for parallel download
	    my $pm = new Parallel::ForkManager(6); 
	    foreach my $uri (@uris) {	       		
		$status{$class}{uris}++;

		my ($protocol,$nothing,$host,$rest,$widget_path,$class,$object,$widget) = split("/",$uri);

#		print STDERR "URI parsing is wrong and screws up logging; confirm the following entries and fix\n";
#		print STDERR "uri : $uri\n";
#		print STDERR "protocol is $protocol\n";
#		print STDERR "Nothing  is $nothing\n";
#		print STDERR "host     is $host\n";
#		print STDERR "rest     is $rest\n";		
#		print STDERR "widget_path is $widget_path\n";
#		print STDERR "class   is $class\n";
#		print STDERR "object is $object\n";
#		print STDERR "widget is $widget\n";
#		die;

		my $cache_start = time();		
		$pm->start and next; # do the fork
		my $cache_stop = time();
		
		my $content = get($uri) or
		    print ERROR join("\t",$class,$object,$widget,$uri,'failed',$cache_stop - $cache_start),"\n";
		
	        if ($content) {
		    my $cache_stop = time();
		    $status{$class}{widgets}{$widget}++;
		    print OUT join("\t",$class,$object,$widget,$uri,'success',$cache_stop - $cache_start),"\n";
		} else {
		    print CLASS_ERROR join("\t",$class,$object,$widget,$uri,'failed',$cache_stop - $cache_start),"\n";
		}
		    
		$pm->finish; # do the exit in the child process
	    }
	    $pm->wait_all_children;
	 
	    if ($status{$class}{objects} > 0 && $status{$class}{objects} % 10 == 0 && defined $status{$class}{uris}) {
		print STDERR "   cached $status{$class}{objects} $class objects and $status{$class}{uris} uris; last was $obj";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
	    }   
	}

#	if ($status{$class}{objects} > 0 && $status{$class}{objects} % 10 == 0 && defined $status{$class}{uris}) {
	    my $end = time();
	    my $seconds = $end - $start;
	    print MASTER "CLASS: $class\n";
	    print MASTER "TOTAL OBJECTS: $status{$class}{objects}\n";
	    print MASTER "Time required to cache " . $status{$class}{objects} . ' objects / ' . $status{$class}{uris} . ' uris: ';
	    printf MASTER "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
	    foreach my $widget (sort keys %{$status{$class}{widgets}} ) {
		my $missing = $status{$class}{objects} - $status{$class}{widgets}{$widget};
		my $percent = ($missing / $status{$class}{objects}) * 100;
		print MASTER "\t$widget\t$status{$class}{widgets}{$widget}/$status{$class}{objects} -- $missing widgets missing ($percent)\n";
	    }
	    print MASTER "\n\n";
#	}
	close OUT;

#	# If we're generating HTML and then bulk-loading to couch...
#	# Bulk load to couchdb. Not done.
#	if ($load_type eq 'bulk_load') {
#	    #
#	}

    }
}	











sub precache_classic_content {
    my ($self) = @_;
    my $base_url = $self->queries_to;  # typically: localhost:8080

    # Kludge: strip trailing slash: breaks processing below.
    $base_url =~ s/\/$//;

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
    
    # URL-ify (specific escaping for couch lookups)
    $name =~ s/\#/\%2523/g;
    $name =~ s/\:/\%253A/g;
    $name =~ s/\s/\%2520/g;
    $name =~ s/\[/\%255B/g;
    $name =~ s/\]/\%255D/g;


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
#	my $complete_flag = `tail -1 $file`;
#	chomp $complete_flag;
#	if ($complete_flag eq 'COMPLETE') {
#	    $previous{$complete_flag}++;
#	    return %previous;
#	}

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



sub _parse_cached_classes_log {
    my ($self,$cache_log) = @_;
    $self->log->info("  ---> parsing log of previously cached classes at $cache_log");
    my %previous;
    if (-e "$cache_log") {
#	# First off, just tail the file to see if we're finished.
#	my $complete_flag = `tail -1 $cache_log`;
#	chomp $complete_flag;
#	if ($complete_flag =~ /COMPLETE/) {
#	    $previous{COMPLETE}++;
#	    $self->log->info("  ---> all widgets already cached.");
#	    return %previous;
#	}

	open IN,"$cache_log" or die "$!";

	while (<IN>) {
#	    if (/COMPLETE/) {
#		$previous{COMPLETE}++;
#		next;
#	    }
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
