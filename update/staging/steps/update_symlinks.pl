#!/usr/bin/perl

use strict;

# If provided with a release, assume we also want to create symlinks.
my $current_release = shift;

my $FTP_SPECIES_ROOT  = "/usr/local/ftp/pub/wormbase/species";
my $FTP_RELEASES_ROOT = "/usr/local/ftp/pub/wormbase/releases";

my @species  = glob("$FTP_SPECIES_ROOT/*") or die "$!";

my @releases;
if ($current_release) {
    @releases = ($current_release);
} else {
    my @releases = glob("$FTP_RELEASES_ROOT/*") or die "$!";
}

foreach my $release (@releases) {
    next unless /^WS\d\d.*/;
    my @species = glob("$FTP_RELEASES_ROOT/$release/species/*");

    foreach my $species (@species) {
	next if /README/;
	# Create a symlink to each file in /species
	opendir DIR,"$FTP_RELEASES_ROOT/$release/species/$species" or die "Couldn't open the dir: $!";
	while (my $file = readdir(DIR)) {

	    chdir "$FTP_SPECIES_ROOT/$species";
	    mkdir("gff") or die "$!";	    
	    mkdir("sequence");
	    chdir("sequence");
	    mkdir("genomic");
	    mkdir("transcripts");
	    mkdir("protein");
	    
	    # GFF?
	    chdir "$FTP_SPECIES_ROOT/$species";
	    if ($file =~ /gff/) {

		chdir("gff") or die "$!";
		create_symlink("../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /genomic|sequence/) {
		chdir("genomic") or die "$!";
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /transcripts/) {
		chdir("transcripts") or die "$!";
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /wormpep|protein/) {
		chdir("protein");
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
		
		# Annotations
	    } elsif ($file =~ /best_blast/) {
		chdir "$FTP_SPECIES_ROOT/$species";
		mkdir("annotation");
		chdir("annotation");
		mkdir("best_blast_hits");
		chdir("best_blast_hits");
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    }


	    # To-do once I see what structure looks like in WS226.
	    # releases/RELEASE/species/SPECIES/annotation.	    
	}
    }
}
	



sub create_symlink {
    my ($target,$filename,$release) = @_;
    symlink($target,$filename);
    if ($current_release) {
	$file =~ s/$release/current/;
	symlink($target,$filename);
    }
}
