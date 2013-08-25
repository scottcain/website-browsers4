# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Flickr::API::Simple' ); }

my $object = Flickr::API::Simple->new ();
isa_ok ($object, 'Flickr::API::Simple');


