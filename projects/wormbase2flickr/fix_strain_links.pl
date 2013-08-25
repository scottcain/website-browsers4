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

for (my $i=1;$<=15;$i++) {
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
#	$description =~ s/flickr\.com\/groups\/869508\\\@N22/flickr\.com\/groups\/869508\@N22/;
	$description =~ s/db\/misc\/strain/db\/gene\/strain/g;
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
    } 
    print Dumper($response) if DEBUG;
    print "Response: $response\n" if DEBUG;
  } 
  print STDERR "processed " . ($c/2) . " photos\n";
}
