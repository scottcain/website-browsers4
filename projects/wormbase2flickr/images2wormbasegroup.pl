#!/usr/bin/perl

use strict;
use lib '.';
use WormBase2Flickr;

my $version = '0.01';
my $wb2flickr = WormBase2Flickr->new();

my $photos = $wb2flickr->get_user_photos(user => 'wormbase');
$wb2flickr->post_images_to_group(photos => $photos);
