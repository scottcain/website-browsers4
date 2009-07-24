#!/usr/bin/perl
use strict;
$|++;  # VERY IMPORTANT! Do not buffer output

use constant DEBUG => 0;

open ERR,">>/usr/local/squid/var/logs/redirector.debug" if DEBUG;

# Eeks! Something has gone wrong. Send all traffic to (basically) one machine)
#my @servers = qw/aceserver blast unc gene vab local/;
#my %servers = map { $_ => aceserver.cshl.org } @servers;
#$servers{crestone} = 'crestone.cshl.edu:8080;
#$servers{biomart}  = 'biomart.wormbase.org';


my %servers = (
	       aceserver => 'aceserver.cshl.org:8080',
	       blast     => 'blast.wormbase.org:8080',
	       unc       => 'unc.wormbase.org:8080',
#	       unc       => 'vab.wormbase.org',
###	       unc       => 'vab.wormbase.org:8080',
	       crestone  => 'crestone.cshl.edu:8080',
	       gene      => 'gene.wormbase.org:8080',
#	       gene      => 'vab.wormbase.org:8080',
	       vab       => 'vab.wormbase.org:8080',
###	       vab      => 'gene.wormbase.org:8080',
	       'local'   => 'brie6.cshl.org:8080',
	       biomart   => 'biomart.wormbase.org',
	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',
	       be1       => 'be1.wormbase.org:3000',

	       # Where we are serving static content from
#	       static    => 'gene.wormbase.org:8080',
	       static    => 'vab.wormbase.org:8080',

	       # Servers converted to the new directory layout
	       freeze1   => 'freeze1.wormbase.org:8080',

	       brie3     => 'brie3.cshl.org:8080',

	       );

my %uris2servers = (
		    '/db/gene/antibody/'   => 'freeze1',
		    '/db/gene/operon/'     => 'freeze1',
		    '/db/gene/gene_class/' => 'freeze1',
		    '/db/gene/motif/'      => 'freeze1',
		    '/db/gene/regulation/' => 'freeze1',
		    '/db/misc/site_map/'   => 'freeze1',
		    '/protein/'            => 'freeze1',
		    );



# URIs matching these values will be sent to brie6

# Conditionally set destinations depending on which server we are running.
# This is simply for emergency purposes if we happen to be running squid on vab or gene.
my $server_name = `hostname`;
chomp $server_name;

my ($uri,$client,$ident,$method);
while (<>) {
    ($uri,$client,$ident,$method) = split();

    my $request = $_;
    if (DEBUG) {
	print ERR "REQUEST: $request\n";
	print ERR "URI    : $uri\n";
	print ERR "CLIENT : $client\n\n";
    }


    # next unless ($uri =~ m|^http://roundrobin.wormbase.org/(\S*)|);
    my ($params) = $uri =~ m|^http://.*\.org/(\S*)|;
    
    my $destination; 

    # Relocated from below - I really hope this doesn't kill anything!
    # Send blast, blat, and epcr queries to blast.wormbase.org
    if ($client =~ /65\.55/) {
	$destination = $servers{unc};
	$uri = "/db/misc/not_found";
	$params = "";

    } elsif ($uri =~ /searches\/blat/ || $uri =~ /blast_blat/ || $uri =~ /searches\/epcr/ || $uri =~ /panzea/
	     || $uri =~ /searches\/strains/) {
	$destination = $servers{blast};
#	$destination = $servers{gene};
	
    } elsif ($uri =~ /genome/) {
	$destination = $servers{unc};
    
    # First, let's map dynamically generated images to their correct backend server
    # based on the server name stub stashed in the URL
    # This will NOT include gbrowse images
#    if ($uri =~ /img\/(.*?)\// && $uri !~ /ace_images\/gbrowse/) {
    # Server keywords are less than 6 letters in length
    } elsif (($uri =~ /img\/(.*?)\// && $1 < 10 && $uri !~ /gbrowse_img/ && $uri !~ /forums/
	     && $uri !~ /mckay/)
	     ||
	     ($uri =~ m|images/gbrowse/(.*?)/| && $1 < 10 && $uri !~ /gbrowse_img/ && $uri !~ /forums/
	      && $uri !~ /mckay/)
	     || 
	     ($uri =~ m|dynamic_images/(.*?)/| && $1 < 10)) {
	
	# mckay is tempo hack for images for the blast_blat page. Ugh.
	my $server = $1;
	$destination = $servers{$server};

	print ERR "URI: $uri\n";
	print ERR "SERVER:  $server\n";
	print ERR "DESTINATION: $destination\n";	

	# Redirect WormMart queries to biomart.wormbase.org
	# ARRGGH!  All sorts of various javascript paths around
	# Make sure these requests don't end up at blast.wormbase.org
    } elsif ($uri =~ /biomart/i || $uri =~ /martview/ || $uri =~ /gfx/
	     || ($uri =~ /Multi/i && $uri !~ /tree/)) {
#	     || ($uri =~ /js/ && $uri !~ /gbrowse\/js/ && $uri !~ /mt\-static/ && $uri !~ /nbrowse/)
#	     || $uri =~ /Biomart/i
#	     || $uri =~ /gfx/
#	     || $uri =~ /EnsEMBL\.css/i
#	     || $uri =~ /EnsEMBL\-mac\.css/i
#	     || $uri =~ /martview/i) {

	$params =~ s|/Multi/martview|/biomart/martview|;

	$destination = $servers{biomart};

    # The freeze1 and freeze2 servers are relatively lightweight blades.
    # Let's just send them simple pages for now.
    # These pages have all ben confirmed to work with the new directory layout.
    } elsif (
	        $uri =~ /\/db\/gene\/antibody/
	     || $uri =~ /\/db\/gene\/operon/
	     || $uri =~ /\/db\/gene\/gene_class/
	     || $uri =~ /\/db\/gene\/motif/
	     || $uri =~ /\/db\/gene\/regulation/
	     || $uri =~ /\/db\/gene\/strain/
	     || $uri =~ /\/db\/misc\/site_map/
	     || $uri =~ /protein/
	     ) {
	$destination = $servers{freeze1};

	# Handle requests for expression images and overlays
	# It would be optimal to serve all static content from
	# a single server...
#    } elsif ($uri =~ /db\/gene\/expression/ || $uri =~ /images\/expression\/assembled/ || $uri =~ /images\/expression\/overlays/) {
#    } elsif ($uri =~ /db\/gene\/expression/) {
#	$destination = $servers{gene};

	# Send to vab:
	# GBrowse images
	# Gbrowse requests
	# The Sequence and Clone  pages
	# Gbrowse image URLs look like this:
	# /ace_images/gbrowse/wormbase/img/f9039a850083d91ee4e36b5cebdfd0af.png

	# All static content goes to be1 (as well as the expression script
	# which may need to generate an image dynamically first)
    } elsif ($uri =~ /images\/expression/ || $uri =~ /db\/gene\/expression/) {
	$destination = $servers{static};


	# Where should gbrowse go?
	# Should we send it all to brie3?
    } elsif ($uri =~ /seq\/gbrowse/ || $uri =~ /gbrowse\/tmp/ || $uri =~ /gbgff/ 
	     || $uri =~ /tmp\/gbrowse/ || $uri =~ /gbrowse_img/ || $uri =~ /aligner/) {
#	$destination = $servers{vab};
	$destination = $servers{brie3};
	print ERR "1 routing to: $destination $uri\n" if DEBUG;

	# Send the gene and sequence pages to vab.
    } elsif ($uri =~ /gene\/gene/) {
	$destination = $servers{vab};

    } elsif ($uri =~ /stats/ && $uri !~ /database/ && $uri !~ /forum/) {
	# Send access stats to unc (still)
	$destination = $servers{unc};

	#  A bit of a misnomer - let gene handle variation, protein, and sequence. Heh.
    } elsif ($uri =~ /gene\/variation/
	     || $uri =~ /seq\/sequence/
	     || $uri =~ /gene\/strain/
	     || $uri =~ /ontology/
	     || $uri =~ /protein/
# seq/protein and ace_images need to be generated on the same server
# since the protein script does not generate a suitable URL
# for revealing identity of back end machine for images.
#	     || $uri =~ /seq\/protein/
#	     || $uri =~ /ace_images\/elegans/
	     || $uri =~ /seq\/clone/ 
	     || $uri =~ /misc\/person/
	     || $uri =~ /misc\/paper/
	     || $uri =~ /cell/
	     || $uri =~ /db\/misc\/session/  # session management
	     || $uri =~ /api\/citeulike/
	     ) {

	$destination = $servers{gene};

	# Whoops! Squid is running on gene.  Something has gone horribly wrong with fe.wormbase.org
	# Change the destination for these scripts to vab
	$destination = $servers{vab} if $server_name =~ /gene/i;
	
	# Send to aceserver: wb_query, aql_query, class_query, cisortho
    } elsif ($uri =~ /wb_query/ || $uri =~ /aql_query/ || $uri =~ /class_query/ || $uri =~ /cisortho/
	     || $uri =~ /searches\/batch_genes/ || $uri =~ /searches\/advanced\/dumper/) {
	$destination = $servers{aceserver};
	
#	# Send blast, blat, and epcr queries to blast.wormbase.org
#    } elsif ($uri =~ /searches\/blat/ || $uri =~ /blast_blat/ || $uri =~ /searches\/epcr/) {
#	$destination = $servers{blast};
	
	# Send the forums, wiki, MT, RSS and the index page to crestone
    } elsif ($uri =~ /wiki/ || $uri =~ /.*\/rearch\/.*/ || $uri =~ /forums/ 
	     && $uri !~ /steinlab/) {
	$destination = $servers{crestone};
	
	# Hack to get around MediaWiki's weird redirect
	$params = 'wiki/index.php/Main_Page' if $params eq 'wiki';

	# Catch problems with forum URLs too. Need to append the back slash.
	$params = 'forums/' if $params eq 'forums';

	$destination = $servers{gene} if $uri =~ /inline_feed/;

	# Continue to send these requests to unc
    } elsif ($uri =~ /movable/ || $uri =~ /mt\-static/ || $uri =~ /mt\//
	     || $uri =~ /rss/
	     || $params eq 'index.html' || $params eq '') {
	$destination = $servers{unc};

	# The cachemgr resides on the local host. Duh.
    } elsif ($uri =~ /.*squid\/cachemgr\.cgi/) {
	print "\n";
	return;

	# The autocomplete database and gbrowse js
	# This should be available on all backend machines
    } elsif ($uri =~ /autocomplete/) {
	$destination = $servers{unc};
	
    } elsif ($uri =~ /gbrowse\/js/ || $params =~ /^js/) {
	$destination = $servers{unc};

    } elsif ($uri =~ /nbrowse/i) {
	$destination = 
	    ($uri =~ /nbrowse_t/)
	    ? $servers{nbrowsejsp}
	: $servers{nbrowse};
        # Catch problems with select URLs. Need to append the back slash.
        $params = 'db/nbrowse/temp_data/' if $params eq 'db/nbrowse/temp_data';

    } elsif ($uri =~ /geomap/ || $uri =~ /geo_map/ || $uri =~ /misc\/wb_people/) {
	$destination = $servers{gene};

    # We still need to send select things to unc
    } elsif ($uri =~ /mailarch/) {
	$destination = $servers{unc};

	# Send HTML requests to brie6
	# I hope this doesn't break anything!
	# Also make sure that sitemap requests go to brie6
    } elsif ($uri =~ /steinlab/) {
	$destination = 'formaggio.cshl.edu/wiki/index.php';
	$params =~ s/steinlab\///g;
    } elsif ($uri =~ /\.html/ || $uri =~ /sitemap.*gz/ || $uri =~ /sitemap.*xml/) {
	$destination = $servers{unc};
    } else {
	# Send all else to brie6
	#$destination = $servers{unc};

	# Now brie6 is the primary acedb host
	# Other httpd requests will be handled
	# by vab
	$destination = $servers{vab};
    }
    
    $uri = "http://$destination/$params";
    print ERR "$uri\n" if DEBUG;
} continue {
    print "$uri\n";
}

