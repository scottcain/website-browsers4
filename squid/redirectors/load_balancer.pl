#!/usr/bin/perl
use strict;
$|++;  # VERY IMPORTANT! Do not buffer output

use constant DEBUG => 0;

open ERR,">>/usr/local/squid/var/logs/err" if DEBUG;
my @servers = ('unc.wormbase.org','vab.wormbase.org');

# URIs matching these values will be sent to brie6
# Performance - prioritize below instead
my @to_primary = map { $_ => 1 } [qw/mailarch feedback rss manage_newsfeeds/];

my ($uri,$client,$ident,$method);
while (<>) {
	($uri,$client,$ident,$method) = split();
 	print ERR $_,"\n" if DEBUG;
        # next unless ($uri =~ m|^http://roundrobin.wormbase.org/(\S*)|);
        my ($params) = $uri =~ m|^http://.*\.org/(\S*)|;

        my $destination; 
       if ($uri =~ /.*squid\/cachemgr\.cgi/) {
	   print "\n";
           return;
       } elsif ($uri =~ /.*\/gbrowse\/.*/) {
           $destination = $servers[1];
       } elsif ($uri =~ /.*\/rearch\/.*/) {
           $destination = 'crestone.cshl.edu';
       # Send requests for the mailarch, rss, or feedback form to the primary server
       } elsif ($uri =~ /.*\/mailarch\/.*/ || $uri =~ /.*\/feedback$/ || $uri =~ /.*\/rss\/.*/ 
	  || $uri =~ /.*\/manage_newsfeed$/) {
           $destination = $servers[0];
       } elsif ($uri =~ /.*wormbase.*/) {
           $destination = $servers[int(rand(scalar(@servers)))]; 
       } else {
            # Send all requests for any virtual hosts to www.wormbase.org   
            $destination = $servers[0];        
       } 

       $uri = "http://$destination/$params";
       # print ERR $uri,"\n";

} continue {
	print "$uri\n";
}
	
