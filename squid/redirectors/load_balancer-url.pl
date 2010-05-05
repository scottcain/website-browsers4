#!/usr/bin/perl
use strict;
$|++;  # VERY IMPORTANT! Do not buffer output

use constant DEBUG      => 0;
use constant DEBUG_FULL => 0;

open ERR,">>/usr/local/squid/var/logs/redirector.debug" if DEBUG || DEBUG_FULL;

# Eeks! Something has gone wrong. Send all traffic to (basically) one machine)
#my @servers = qw/aceserver blast unc gene vab local/;
#my %servers = map { $_ => aceserver.cshl.org } @servers;
#$servers{crestone} = 'crestone.cshl.edu:8080;
#$servers{biomart}  = 'biomart.wormbase.org';



my %servers = (
	       aceserver => 'aceserver.cshl.org:8080',
	       blast     => 'blast.wormbase.org:8080',
	       unc       => 'unc.wormbase.org:8080',
	       crestone  => 'crestone.cshl.edu:8080',
	       gene      => 'gene.wormbase.org:8080',
#	       gene      => 'brie3.cshl.org:8080',

	       vab       => 'vab.wormbase.org:8080',
	       biomart   => 'biomart.wormbase.org',
	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',
	       
	       # Where we are serving static content from (not currently in use)
	       static    => 'vab.wormbase.org:8080',

	       freeze1   => 'freeze1.wormbase.org:8080',
	       freeze2   => 'freeze2.wormbase.org:8080',
	       
	       brie3     => 'brie3.cshl.org:8080',       
#	       brie3     => 'be1.wormbase.org:8080',       
	       be1       => 'be1.wormbase.org:8080',
#	       be1     => 'brie3.cshl.org:8080',

	       synteny   => 'mckay.cshl.edu',
	       "oicr-gbrowse" => '206.108.125.173',

	       # oicr-community: wiki, forums, blog
	       "oicr-community" => '206.108.125.176',
	       );

=pod

# 2009.09 - Server migration step 1: be1 and brie3 offline; brie6 up
my %servers = (
	       aceserver => 'aceserver.cshl.org:8080',
	       blast     => 'vab.wormbase.org:8080',
	       unc       => 'unc.wormbase.org:8080',
	       crestone  => 'crestone.cshl.edu:8080',
	       gene      => 'vab.wormbase.org:8080',

	       vab       => 'vab.wormbase.org:8080',
	       biomart   => 'biomart.wormbase.org',
	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',
	       
	       # Where we are serving static content from (not currently in use)
	       static    => 'vab.wormbase.org:8080',

	       freeze1   => 'freeze1.wormbase.org:8080',
	       freeze2   => 'freeze2.wormbase.org:8080',
	       
	       brie3     => 'vab.wormbase.org:8080',       
	       be1       => 'unc.wormbase.org:8080',	       
	       );



# 2009.09 - Server migration step 1: be1 and brie3 offline; brie6 up
my %servers = (
	       aceserver => 'aceserver.cshl.org:8080',
	       blast     => 'blast.wormbase.org:8080',
	       unc       => 'be1.wormbase.org:8080',
	       crestone  => 'crestone.cshl.edu:8080',
	       gene      => 'gene.wormbase.org:8080',

	       vab       => 'vab.wormbase.org:8080',
	       biomart   => 'biomart.wormbase.org',
	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',
	       
	       # Where we are serving static content from (not currently in use)
	       static    => 'vab.wormbase.org:8080',

	       freeze1   => 'freeze1.wormbase.org:8080',
	       freeze2   => 'freeze2.wormbase.org:8080',
	       
	       brie3     => 'be1.wormbase.org:8080',       
	       be1       => 'be1.wormbase.org:8080',	       
	       );


=cut

# Conditionally set destinations depending on which server we are running.
# This is simply for emergency purposes if we happen to be running squid on vab or gene.
my $server_name = `hostname`;
chomp $server_name;

my ($uri,$client,$ident,$method);
while (<>) {
    ($uri,$client,$ident,$method) = split();
    
    my $request = $_;
    
    if (DEBUG_FULL) {
	print ERR "REQUEST: $request\n";
	print ERR "URI    : $uri\n";
	print ERR "CLIENT : $client\n\n";
    }
    
    # next unless ($uri =~ m|^http://roundrobin.wormbase.org/(\S*)|);
    
    # Parse out params from the URI
    my ($params) = $uri =~ m{^http://.*\.org/(\S*)};
    
    # Set up the default destiation
    my $destination = $servers{brie3};
    
    # Instead of a bunch of insane conditional if/else statements,
    # we will bomb out of the while as soon as we find a good URL.
    # This still requires soe careful ordering of request evaluation
    # but it is easier to follow and cleaner code.




    
    ##########################################################
    #
    #  GBrowse2 (at OICR)
    # 
    if ( $uri =~ m{gb2} 
	 ||
	 $uri =~ m{gbrowse2}
	 ) {
#	$params =~ s|db/gb2|db/seq|g;

	$destination = $servers{"oicr-gbrowse"};
	$uri = "http://$destination/$params";
	next;
    }


    
    ##########################################################
    #
    #  The computationally intensive gene page
    #  Check for it first since this is the most prominent request
    if ($uri =~ m{gene/gene}
	 || $uri =~ m{/db/gene/operon}
	) {

	$destination = $servers{be1};
	print ERR "Routing Gene Page query ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    
    
    # The synteny browser (for now)
    if ($uri =~ m{cgi-bin/gbrowse_syn}
	|| $uri =~ m{gbrowse/tmp/.*synteny}
	|| $uri =~ m{gbrowse/tmp/compara}
	) {       
	$destination = $servers{synteny};
	$uri = "http://$destination/$params";
	next;
    }


    ##########################################################
    #
    #  Dynamic images, specific to generating back-end server
    #  Server keywords are embedded in the URL and less than 
    #  6 letters in length forum images are handled elsewhere.
    #  Currently this INCLUDES GBrowse images.
    if (($uri =~ m{img/(.*?)/} && $1 < 10 && $uri !~ m{gbrowse_img} && $uri !~ m{forums}
	 && $uri !~ m{mckay})
	||
	($uri =~ m{images/gbrowse/(.*?)/} && $1 < 10 && $uri !~ m{gbrowse_img} && $uri !~ m{forums}
	 && $uri !~ m{mckay})
	|| 
	($uri =~ m{dynamic_images/(.*?)/} && $1 < 10)
	
	# Uncomment to INCLUDE gbrowse generated images
	||
	($uri =~ m{tmp/gbrowse/(.*?)/} && $1 < 10)
	) {
	
	# mckay is tempo hack for images for the blast_blat page. Ugh.
	my $server = $1;
	$destination = $servers{$server};
	
	print ERR "Routing dynamic images ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }	
    
    
    ##########################################################
    #
    #  The Genome Browser and components,
    #  another often used page
    
    if (  $uri =~ m{seq/gbrowse} 
	  || $uri =~ m{gbgff}
#	  || $uri =~ m{tmp/gbrowse}    # temporary images; should possibly be included in dynamic images above
	  || $uri =~ m{gbrowse/tmp}    # temporary images (old structure)
	  || $uri =~ m{gbrowse_img}   
	  || $params =~ m{^gbrowse}     # Gbrowse js must be served from same node?
	  || $uri =~ m{aligner}  
	  ) {
	
	$destination = $servers{brie3};
	
	print ERR "Routing Genome Browser ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
        

    ##########################################################
    #
    #  The Home Page
    if ( $params eq ''
	 || $uri eq 'http://www.wormbase.org/'
	 || $uri eq 'http://wormbase.org/'
	 || $uri =~ m{gene/strain} ) {
	$destination = $servers{brie3};
	
	print ERR "Routing MT ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    

    ##########################################################
    #
    #  Manually redistribute some CGIs (Tier I)
    if (  $uri =~ m{searches/basic} ) {
	$destination = $servers{be1};
	print ERR "Routing CGIs Tier I ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }
    

    ##########################################################
    #
    #  Manually redistribute some CGIs (Tier II)
    if (  $uri =~ m{seq/sequence} ) {
	$destination = $servers{gene};
	print ERR "Routing CGIs Tier II ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }


    ##########################################################
    #
    #  The Blog
    if ($params =~ m{blog}) {
	$destination = $servers{"oicr-community"};

	# Whoops!  This might be a request for the inline_feed script
	# which contains the blog rss feed as a parameter. Doh!
	if ($uri =~ /inline_feed/) {
	    $destination = $servers{gene};
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
    #  Manually redistribute some CGIs (Tier III)
    if (   $uri =~ m{gene/variation}
	   || $uri =~ m{ontology}
	   || $uri =~ m{db/misc/session}  # session management
	   || $uri =~ m{api/citeulike}
	   || $uri =~ m{gene/expression}
	   ) {
	
	$destination = $servers{gene};
	print ERR "Routing CGIs Tier III ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }
    
    
    ##########################################################
    #
    #  Manually redistribute some CGIs (Tier IV)    
    if (   $uri =~ m{/db/gene/antibody}
	   || $uri =~ m{/db/gene/gene_class}
	   || $uri =~ m{/db/gene/motif}
	   || $uri =~ m{/db/gene/regulation}
	   || $uri =~ m{/db/gene/strain}
	   || $uri =~ m{/db/seq/protein}
	   ) {
	$destination = $servers{freeze1};
	print ERR "Routing CGIs Tier IV ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }


    
    ##########################################################
    #
    #  Manually distribute some CGIs (Tier V)
    #  Everything that remains in /db/misc
    if ( $uri =~ m{db/misc}
	 ||
	 $uri =~ m{db/gene/expression}
	 ) {

	$destination = $servers{freeze2};

	# Logic hack. 2010.04.13.
        # $destination = $servers{gene} if $uri =~ /inline_feed/;

	print ERR "Routing CGIs Tier V ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";	    
	next;	
    }

    
    ##########################################################
    #
    #  aceserver: miscellaneous programmatic queries
    if (   $uri =~ m{wb_query} 
	   || $uri =~ m{aql_query}
	   || $uri =~ m{class_query} 
	   || $uri =~ m{cisortho}
	   || $uri =~ m{searches/batch_genes}
	   || $uri =~ m{searches/advanced/dumper}
	   ) {
	$destination = $servers{aceserver};
	
	print ERR "Routing query request ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }
    

    ##########################################################
    #
    # Searches: blast, blat, epcr, and "strains"
    if (  $uri =~ m{searches/blat}
	  || $uri =~ m{blast_blat}
	  || $uri =~ m{searches/epcr}
	  || $uri =~ m{searches/strains}
	  ) {
	$destination = $servers{blast};
	
	print ERR "Routing blast/blat/epcr ($uri) to $destination\n" if DEBUG;
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
    #
    #  crestone: wiki and forums
    if ($uri =~ m{wiki} || $uri =~ m{forums}) {
	$destination = $servers{crestone};
	
	# Hack to get around MediaWiki's weird redirect
	$params = 'wiki/index.php/Main_Page' if $params eq 'wiki';
	
	# Catch problems with forum URLs too. Need to append the back slash.
	$params = 'forums/' if $params eq 'forums';
	
	print ERR "Routing wiki/forum ($uri) to $destination\n" if DEBUG;
	$uri = "http://$destination/$params";
	next;
    }


    ##########################################################
    #
    #  Various static content; must come BELOW forum/wiki
    #  Serve basically anything outside of /db from a single box.
    #  This is mostly static content (gbrowse static handled above)
    if (  $params !~ m{^db}) {
	
	# TODO: EVERYTHING EXCEPT FOR THE BLOG COULD BE RANDOM
	$destination = $servers{unc};
	
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
	    $destination = $servers{unc};
	    
	} elsif ($uri =~ /db\/gene\/expression/) {
	    $destination = $servers{vab};
	    
	    
	    # This is probably unnecessary
	    # The autocomplete database
	    # This should be available on all backend machines
	} elsif ($uri =~ /autocomplete/) {
	    $destination = $servers{be1};
	    
	    ####### MISC
	    
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

