package WormBase::Update::Staging::PrecacheContent;

use Moose;
use Ace;
use WWW::Mechanize;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'precache computationally intensive content of the WormBase site',
);

sub run {
    my $self = shift;       
    my $release = $self->release;
    
    foreach my $class (qw/gene variation protein/) {
	$self->precache_classic_content($class);
    }
}


# Precache specific WormBase widgets.
# Use this script to populate the ON DISK (not squid) cache.
# It should be run after a release to populate the cache.
# This SHOULD be responsive to the app's config file
# which has "precache" directives for widgets.
# Oh well.

# The cache will reside at /usr/local/wormbase/shared/cache.
# I will need to sync this to production (and hopefully the
# cache will be portable).
# Cached entries will not be rendered HTML but raw data.

sub precache_content {
    my $self = shift;
    # Class, object name, widget
    my $base_url = 'http://beta.wormbase.org/rest/widget/%s/%s/%s';
    
    my $db      = Ace->connect(-host=>'localhost',-port=>2005);
    
    my %classes = ( gene      => [ qw/overview/ ],
		    variation => [ qw/overview/ ],
		    protein   => [ qw/overview external_links molecular_details homology history/ ],
	);
    
    my $version = $db->status->{database}{version};

    foreach my $class (keys %classes) {
	my $cache = join("/",$self->support_databases_dir,$version,'cache',$class);
	my %previous = _parse_cache_log($cache,$version); 
	system("mkdir -p $cache");
	open OUT,">>$cache/$version-precached-pages.txt";
	my $start = time();
	
	my $ace_class = ucfirst($class);
	my $i = $db->fetch_many($ace_class => '*');
	while (my $obj = $i->next) {
	    
	    if ($previous{$obj}) {
		print STDERR "Already seen $class $obj. Skipping...";
		print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
		next;
	    }
	    
	    print STDERR "Fetching and caching $obj\n";
	    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n"; 
	    
	    my %status;
	    foreach my $widget (@{$classes->{$class}}) {
		my $url = sprintf($base_url,$obj->name,$widget);
		
		my $cache_start = time();
		
		# No need to watch state - create a new agent for each gene to keep memory usage low.
		my $mech = WWW::Mechanize->new(-agent => 'WormBase-PreCacher/1.0');
		$mech->get($url);
		my $success = ($mech->success) ? 'success' : 'failed';
		my $cache_stop = time();
		print OUT join("\t",$class,$obj,$widget,$url,$success,$cache_stop - $cache_start),"\n";
		$status{$class}++;
	    }
	}
	
	my $end = time();
	my $seconds = $end - $start;
	print OUT "\n\nTime required to cache " . (scalar keys %status) . ": ";
	printf OUT "%d days, %d hours, %d minutes and %d seconds\n",(gmtime $seconds)[7,2,1,0];    
	close OUT;
    }
}



sub precache_classic_content {
    my ($self,$class) = @_;
    my $db = Ace->connect(-host=>'localhost',-port=>2005) || die "Couldn't open database";
    
    $|++;
    
    my %class2url = ( gene => 'http://dev.wormbase.org/db/gene/gene?class=Gene;name=',
		      variation => 'http://dev.wormbase.org/db/gene/variation?class=Variation;name=',
		      protein   => 'http://dev.wormbase.org/db/seq/protein?class=Protein;name=',);
    
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
	
	print STDERR "Fetching and caching $obj\n";
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
	open IN,"$cache/$version-precached-pages.txt" or die "$!";
	my %previous;
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
    


1;
