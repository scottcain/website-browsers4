#!/usr/bin/perl

use strict;

use constant FTP_SPECIES_ROOT => "/usr/local/ftp/pub/wormbase/species";

my $species = get_species();
print @$species;

# Get a list of all species on the FTP site
sub get_species {
    my @species;
    opendir DIR,FTP_SPECIES_ROOT or die "Couldn't open the species directory: $!";
    my @species =grep !/^\./, readdir(DIR);
    while (my $species = readdir DIR) {
	next if /^\.*/;
	next if $_ =~ /README/;
	push @species,$species;
    }
    return \@species;
}
