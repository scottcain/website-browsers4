#!/usr/bin/perl
use strict;
$|++;  # VERY IMPORTANT! Do not buffer output

use constant DEBUG      => 0;
use constant DEBUG_FULL => 0;

open ERR,">>/usr/local/squid/var/logs/redirector.debug" if DEBUG || DEBUG_FULL;

# Eeks! Something has gone wrong. Send all traffic to (basically) one machine)
#my @servers = qw/aceserver blast unc gene local/;
#my %servers = map { $_ => aceserver.cshl.org } @servers;
#$servers{biomart}  = 'biomart.wormbase.org';

my %servers = (
	       # Data mining services: blast, blat, queries.
	       # aka wb-mining.oicr.on.ca, and officially mining.wormbase.org
	       # replaces blast.wormbase.org and aceserver.cshl.edu
	       "oicr-mining"  => '206.108.125.178',

	       # Migrating to 
	       # 206.108.125.189 (and/or update DNS entry)
#	       biomart   => 'biomart.wormbase.org',
	       biomart   => '206.108.125.189',

	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',
	       
	       # Where we are serving static content from (not currently in use)
	       #static    => '',

	       # 2010.05.18
	       # Retiring gene, brie3, and brie6
	       # gene      => 'gene.wormbase.org:8080',
	       brie3     => 'brie3.cshl.org:8080',       
	       'oicr-web1' => '206.108.125.175',
#	       'oicr-web1' => '206.108.125.177',

	       # 2010.05.16
               # Retiring freeze1, freeze2
	       # freeze1   => 'freeze1.wormbase.org:8080',
	       # freeze2   => 'freeze2.wormbase.org:8080',
	       be1       => 'be1.wormbase.org:8080',
	       # Now handled by oicr-web2 (aka wb-acedb2.oicr.on.ca)
	       'oicr-web2' => '206.108.125.177',


	       synteny   => 'mckay.cshl.edu',

	       # GBrowse running at OICR. Can run on
	       # non-standard ports since these services
	       # will not be accessed directly.
	       "oicr-gbrowse2" => '206.108.125.173',
	       "oicr-gbrowse1" => '206.108.125.173:8080',

	       # 2010.05.05
	       # Blog, wiki, forums are all at OICR.
	       # Here, we send all requests like "wormbase.org/blog"
	       # to oicr, which then issues a 301 redirect to the subdomain.
	       # Monitor the logs/redirect on this server to gauge
	       # how heavily this is used.
	       # This can probably be retired in the near future.
	       # (As well as all of the configuration for these
	       #  services contained below)
	       "oicr-community-blog"   => '206.108.125.176',
	       "oicr-community-forums" => '206.108.125.176:8081',
	       "oicr-community-wiki"   => '206.108.125.176:8080',
	       );


my $server_name = `hostname`;
chomp $server_name;

my ($uri,$client,$ident,$method);
while (<>) {
    ($uri,$client,$ident,$method) = split();
    
    my $request = $_;
    
    if (DEBUG_FULL) {
	print ERR "REQUEST: $request\n";
	print ERR "URI    : $uri\n";
	print ERR "CLIENT : $client\n";
    }
    
    # next unless ($uri =~ m|^http://roundrobin.wormbase.org/(\S*)|);
    
    # Parse out params from the URI
    my ($params) = $uri =~ m{^http://.*\.org/(\S*)};
    
    # Set up the default destiation
#    my $destination = $servers{brie3};
    my $destination = $servers{"oicr-web1"};
    
    ##########################################################
    #  OICR
    #  GBrowse2
    if ( $uri =~ m{gb2} 
	 ||
	 $uri =~ m{gbrowse2}
	 ||
	 $uri =~ m{gb2-support}
	 ||
	 ($uri =~ m{gbrowse_img} && $uri !~ m{db/seq})
	 ) {
#	$params =~ s|db/gb2|db/seq|g;
	
	$destination = $servers{"oicr-gbrowse2"};
	$uri = "http://$destination/$params";
	next;
    }
    
    
    
    ##########################################################
    #  OICR
    #  The computationally intensive gene page
    #  Check for it first since this is the most prominent request
    if ($uri =~ m{gene/gene}) {
	
	$destination = $servers{be1};
#	$destination = $servers{"oicr-web2"};
	print ERR "Routing Gene Page query ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    
    
    ##########################################################
    #  CSHL: Mckays server
    #  The synteny browser
    if ($uri =~ m{cgi-bin/gbrowse_syn}
	|| $uri =~ m{gbrowse/tmp/.*synteny}
	|| $uri =~ m{gbrowse/tmp/compara}
	) {       
	$destination = $servers{synteny};
	$uri = "http://$destination/$params";
	next;
    }
    

    ##########################################################
    #  CSHL & OICR
    #  Dynamic images. These contain a keyword in the URL
    #  so I can redirect to the appropriate back-end
    #  server that generated the image.
    #     
    #  I think this is now limited to:
    #      protein page: oicr-web2
    #      interaction page pie chart:    brie3
    #      gene/gmap : brie3

    #  Server keywords are embedded in the URL and less than 
    #  10 letters in length forum images are handled elsewhere.
    #  GBrowse images are contained under a blanket URL and
    #  handled elsewhere.
    if ($uri =~ m{dynamic_images/(.*?)/} && $1 < 10) {
	my $server = $1;
	# Convert hostname keywords to server hash key names. Dumb.
	$server = 'oicr-web1'   if $server eq 'wb-web1';
	$server = 'oicr-web2'   if $server eq 'wb-web2';
	$server = 'oicr-mining' if $server eq 'wb-mining';

	$destination = $servers{$server};
	# Finally, handle some 
	if ($uri =~ /pie_chart/
	    ||
	    $uri =~ m{dynamic_images/brie3}) {
	    $destination = $servers{brie3};
	}
	
	print ERR "Routing dynamic images ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    
    # RELOCATED GBrowse 1.x to OICR on 2010.05.08.
    # I *believe* this is now deprecated.
    # All paths instead are self-contained in /gbrowse and set up in the gbrowse config
    
#    ##########################################################
#    #
#    #  The Genome Browser and components,
#    #  another often used page
#    #  For running GBrowse1.x at CSHL....
#    if (  $uri =~ m{seq/gbrowse} 
#	  || $uri =~ m{gbgff}
##	  || $uri =~ m{tmp/gbrowse}    # temporary images; should possibly be included in dynamic images above
#	  || $uri =~ m{gbrowse/tmp}    # temporary images (old structure)
#	  || $uri =~ m{gbrowse_img}   
#	  || $params =~ m{^gbrowse}     # Gbrowse js must be served from same node?
#	  || $uri =~ m{aligner}  
#	  ) {
#	
#	$destination = $servers{brie3};
#	
#	print ERR "Routing Genome Browser ($uri) to $destination\n" if DEBUG;
#	$uri = "http://$destination/$params";
#	next;
#    }

    ##########################################################
    #  CSHL
    #  The EST aligner

    # GBrowse 1.x relocation: Still need to send the aligner to brie3
    # Make sure the aligner still goes to brie3
    if ($uri =~ m{aligner}) {
	$destination = $servers{brie3};
	
	print ERR "Routing Genome Browser ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    
    
    ##########################################################
    #  OICR
    #  Send GBrowse1 requests to OICR.
    if (  $uri       =~ m{seq/gbrowse} 
	  || $uri    =~ m{gbgff}
	  || $uri    =~ m{gbrowse/tmp}    # temporary images (old structure)
	  || $uri    =~ m{gbrowse_img}   
	  || $params =~ m{^gbrowse}     # Gbrowse js must be served from same node?	  
	  || $uri    =~ m{gb1-support}
	  ) {
	
	$destination = $servers{"oicr-gbrowse1"};
	
	print ERR "Routing Genome Browser ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    

    # No longer necessary.
#    ##########################################################
#    #  CSHL
#    #  The Home Page
#    if ( $params eq ''
#	 || $uri eq 'http://www.wormbase.org/'
#	 || $uri eq 'http://wormbase.org/'
#	 ) {
#	$d#estination = $servers{brie3};
#	
#	print ERR "Routing MT ($uri) to $destination\n" if DEBUG;
#	$uri = "http://$destination/$params";
#	next;
#    }
    
        
    ##########################################################
    #  OICR
    #  Manually redistribute some CGIs (Tier II)
    if (  
	  $uri =~ m{gene/variation}
	  || $uri =~ m{ontology}
	  || $uri =~ m{db/misc/session}  # session management
	  || $uri =~ m{api/citeulike}
	  || $uri =~ m{gene/expression}
	  ) {
	
	$destination = $servers{"oicr-web1"};
#	$destination = $servers{gene};
	print ERR "Routing CGIs Tier II ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }
    
       
    
    ##########################################################
    #  OICR
    #  Manually redistribute some CGIs (Tier III)
    if (   $uri =~ m{/db/gene/antibody}
	   || $uri =~ m{/db/gene/gene_class}
	   || $uri =~ m{/db/gene/motif}
	   || $uri =~ m{/db/gene/regulation}
	   || $uri =~ m{/db/gene/strain}
	   || $uri =~ m{/db/gene/operon}
	   || $uri =~ m{/db/seq/protein}
	   || $uri =~ m{seq/sequence}
#	   || $uri =~ m{db/misc/}
	   ) {

	$destination = $servers{"oicr-web2"};
	print ERR "Routing CGIs Tier III ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }
    
     
    # 2010.05.12: Aceserver nearly retired.
    ##########################################################
    #  OICR
    #  mining.wormbase.org: miscellaneous programmatic queries
    #
    # Is searches/blat deprecated?
    if (   $uri    =~ m{wb_query} 
	   || $uri =~ m{aql_query}
	   || $uri =~ m{class_query} 
	   || $uri =~ m{batch_genes}
	   || $uri =~ m{searches/advanced/dumper}
	   || $uri =~ m{searches/epcr}
	   || $uri =~ m{searches/strains}
	   || $uri =~ m{cisortho}
	   || $uri =~ m{blast_blat}
	   || $uri =~ m{searches/blat}
	   || $uri =~ m{searches/basic}
	   ) {
	$destination = $servers{"oicr-mining"};
	
	print ERR "Routing query request ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    
    # 2010.05.05
    # Blog, wiki, forums are all at OICR.
    # Here, we send all requests like "wormbase.org/blog"
    # to oicr, which then issues a 301 redirect to the subdomain.
    # Monitor the logs/redirect on this server to gauge
    # how heavily this is used.
    # This can probably be retired in the near future.
    # (As well as all of the configuration for these
    #  services contained below)

    ##########################################################
    #
    #  The Blog
    if ($params =~ m{blog}) {
	$destination = $servers{"oicr-community-blog"};

	# Whoops!  This might be a request for the inline_feed script
	# which contains the blog rss feed URI as a parameter. Except
	# that the inline_feed script doesn't run from there.
	if ($uri =~ /inline_feed/) {
	    $destination = $servers{brie3};
	    $uri = "http://$destination/$params";	    
	    next;
	}
	
	# Catch problems with some URLs. Need to append the back slash.
	$params = 'blog/' if $params eq 'blog';
	
    	print ERR "Routing blog ($uri) to $destination\n" if DEBUG;
        $uri = "http://$destination/$params";	    
	next;
    }
    
    ##########################################################
    #
    #  The Forums
    #  The fora are now a subdomain: forums.wormbase.org:8081
    #  Port 8081 on the community server will handle 301 redirect.
    #  Redirect added: 2010.05.10
    if ($uri =~ m{forums}) {
	$destination = $servers{"oicr-community-forums"};
	
	# NOT NECESSARY (as long as /misc/ URI handler comes first)
#	# Whoops!  This might be a request for the inline_feed script
#	# which contains the blog rss feed as a parameter. Doh!
	if ($uri =~ /inline_feed/) {
	    $destination = $servers{brie3};
	    $uri = "http://$destination/$params";	    
	    next;
	}
	
	# Catch problems with forum URLs too. Need to append the back slash.
	$params = 'forums/' if $params eq 'forums';
	
    	print ERR "Routing forums ($uri) to $destination/$params\n" if DEBUG;
        $uri = "http://$destination/$params";	    
	next;
    }
    
    
    ##########################################################
    #
    #  The Wiki
    #  The wiki is now a subdomain: wiki.wormbase.org
    #  Port 8080 on the community server will handle 301 redirect.
    #  Redirect added: 2010.05.10
    if ($uri =~ m{wiki}) {
	$destination = $servers{"oicr-community-wiki"};
	
	# Hack to get around MediaWiki's weird redirect
	$params = 'wiki/index.php/Main_Page' if $params eq 'wiki';       
	
	# Hack. Require a trailing slash.
	$params = 'wiki/' if $params eq 'wiki';
	
	print ERR "Routing wiki/forum ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }


     
    
    ##########################################################
    #
    #  biomart
    if (   $uri  =~ m{biomart}i
	   || $uri  =~ m{martview}
	   || $uri  =~ m{gfx}
	   || ($uri =~ m{Multi}i && $uri !~ m{tree})) {
	
	# Substitute old params for new
	$params =~ s|/Multi/martview|/biomart/martview|;
	
	$destination = $servers{biomart};
	
	print ERR "Routing biomart ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }

    ##########################################################
    #
    #  The cachemgr CGI resides on the localhost
    if ($uri =~ m{.*squid/cachemgr\.cgi}) {
	print "\n";
	return;
    }


    ##########################################################
    #  OICR: Static content.
    #  For now, just randomize between web1/web2/mining
    #  Various static content; must come BELOW forum/wiki
    #  Serve basically anything outside of /db from a single box.
    #  This is mostly static content (gbrowse static handled above)
    if (  $params !~ m{^db}) {
	
	my @array = ($servers{"oicr-web1"},$servers{"oicr-web2"},$servers{"oicr-mining"});
	my $range = scalar @array;
	my $index = int(rand($range));
	
	$destination = $array[$index];
	
	print ERR "Routing static content ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }

        

    # This configuration hasn;'t been handled yet
    if (0) {
	if (1) {
	    
	# This needs to be migrated
        # Standard URLs - NOT HANDLED
	} elsif ($uri =~ /genome/) {

	    
	    
	    # This is probably unnecessary
	    # The autocomplete database
	    # This should be available on all backend machines

	    # THis should probably be migrated
	} elsif ($uri =~ /nbrowse/i) {
	    $destination = 
		($uri =~ /nbrowse_t/)
		? $servers{nbrowsejsp}
	    : $servers{nbrowse};
	    # Catch problems with select URLs. Need to append the back slash.
	    $params = 'db/nbrowse/temp_data/' if $params eq 'db/nbrowse/temp_data';
	    
	} else {}	
    }
    
    print ERR "Routing fall-through: $uri to default server $destination\n" if DEBUG;    
    $uri = "http://$destination/$params";
    
} continue {
    print "$uri\n";
}

