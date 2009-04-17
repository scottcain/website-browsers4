#!/usr/bin/perl

use strict;
use Flickr::API;
use Flickr::API::Request;
use Data::Dumper;
use CGI;
use lib '.';
use WormBase2Flickr;

use constant DEBUG => 0;
my $version = '0.01';

my $wb2flickr = WormBase2Flickr->new();

for (my $i=2;$<=15;$i++) {
    my $photos = $wb2flickr->get_user_photos(user => 'wormbase',
					     page => $i);
    update_photos($photos);
}


sub update_photos {
  my $photos = shift;
  my $c = 1;
  foreach (@$photos) { 

    $c++;
    # Even numbered hashes are empty
    next if $c % 2 == 0;

    my $id = $_->{attributes}->{id}; 

    print STDERR "processing $c: $id\n";
    
    # Get the current description
    my $request = new Flickr::API::Request({
					    'method' => 'flickr.photos.getInfo',
					    args => { photo_id => $id }
					   });
    
    my $api = $wb2flickr->api;
    my $response = $api->execute_request($request);
    
    # Fetch the current description from the returned data
#    print Dumper($response);
    my $description = $response->{tree}->{children}->[1]->{children}->[5]->{children}->[0]->{content};
    my $title       = $response->{tree}->{children}->[1]->{children}->[3]->{children}->[0]->{content};
    
    if (DEBUG) {
	print $description;
	print $title;
    }

    if ($description) {
	# Fix the link to the group which is broken in many images.
	$description =~ s/flickr\.com\/groups\/869508\\\@N22/flickr\.com\/groups\/869508\@N22/;
	$description =~ s/&lt;/\</g;
	$description =~ s/&gt;/\>/g;
	$description =~ s/&quot;/\"/g;
	
	
	# Update the description
	my $request = new Flickr::API::Request({
	    'method' => 'flickr.photos.setMeta',
	    args => { photo_id => $id,
		      api_key  => $wb2flickr->api_key,
		      title    => $title,
		      description => $description,
		      auth_token  => $wb2flickr->auth_token,
	    }
					       });

	my $response = $api->execute_request($request);
	print Dumper($response) if DEBUG;

	
	# Add the expression pattern as a tag
	# Get the expression pattern - need to add this as a tag
	$description =~ /http:\/\/www\.wormbase\.org\/db\/gene\/expression\?name=(.*)\"\>/;
	my $expression_pattern = $1;

	my $request = new Flickr::API::Request({
	    'method' => 'flickr.photos.addTags',
	    args => { photo_id => $id,
		      api_key  => $wb2flickr->api_key,
		      auth_token  => $wb2flickr->auth_token,
		      tags        => $expression_pattern,
	    }
					       });
	
	my $response = $api->execute_request($request);
	print Dumper($response) if DEBUG;
	
=pod

<b>WormBase Expression Pattern: </b><a href="http://www.wormbase.org/db/gene/expression?name=Expr7759">Expr7759</a>

<b>Expression of: </b><a href="http://www.wormbase.org/db/gene/gene?name=WBGene00022671">ZK177.3</a>

<b>Pattern: </b>Weak expression in anterior and posterior intestine is only seen post embryonically.

<b>Associated Anatomy Ontology Terms</b>
<a href="http://www.wormbase.org/db/ontology/anatomy?name=WBbt:0005772">intestine (WBbt:0005772)</a>

<b>Experimental Details</b>
<b>Type: </b>reporter gene [ZK177.3::gfp] transcriptional fusion. GFP fusion made by Gateway recombination in pDEST-DD04. Transformation by unc-119 rescue - non-integrated lines segregate uncoordinated non-transgenics. Other strains: UL2245, UL2246.
<b>Strain: </b><a href="http://www.wormbase.org/db/misc/strain?name=UL2244">UL2244</a>

<b>Remarks: </b>Clone: pUL#JRH7F11

<b>References</b>
1. <a href="http://www.wormbase.org/db/misc/paper?name=WBPaper00029055">Reece-Hoyes JS et al. (2007) BMC Genomics.  Insight into transcription factor gene duplication from Caenorhabditis ....</a>

<i>Original image: 29055ZK993.1_2.jpg</i>

<i>NOTE: This image has been added to Flickr by <a href="http://www.wormbase.org/">WormBase</a> staff. Notice problems with the annotations?  Feel free to leave a comment here.  If you would like to add your <b>own</b> expression patterns for automatic display on WormBase, please see the <a href="http://MATCHED/">WormBase Group</a> right here on Flickr!.</i></b>

=cut



    }
           
    print Dumper($response) if DEBUG;
    print "Response: $response\n" if DEBUG;
  }

  print STDERR "processed " . ($c/2) . " photos\n";
}


