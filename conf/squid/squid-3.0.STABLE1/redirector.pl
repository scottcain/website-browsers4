#!/usr/bin/perl
use strict;
$|++;  # VERY IMPORTANT! Do not buffer output

use constant DEBUG => 1;

open ERR,">>/home/todd/redirector_debug" if DEBUG;

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
	       vab       => 'vab.wormbase.org:8080',
###	       vab       => 'vab.wormbase.org',
###	       vab      => 'gene.wormbase.org:8080',
	       'local'   => 'brie6.cshl.org:8080',
	       biomart   => 'biomart.wormbase.org',
	       nbrowse   => 'gene.wormbase.org:9002',
	       nbrowsejsp => 'gene.wormbase.org:9022',

	       # Where we are serving static content from
	       static    => 'gene.wormbase.org:8080',
	       );

# URIs matching these values will be sent to brie6

# Conditionally set destinations depending on which server we are running.
# This is simply for emergency purposes if we happen to be running squid on vab or gene.
my $server_name = `hostname`;
chomp $server_name;

my ($uri,$client,$ident,$method);
while (<>) {
    ($uri,$client,$ident,$method) = split();

    my $destination = $servers{crestone} if $uri =~ /forums/;
    my ($params) = $uri =~ m|^http://.*\.org/(\S*)|;

    $uri = "http://$destination/$params";
    print ERR "$uri $client $ident\n" if DEBUG;
} continue {
    print "$uri\n";
}
