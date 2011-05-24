#!/usr/bin/perl

# TODO: 
# Update mysql db symlinks on go live
# Update acedb symlink on go live

use strict;

# If provided with a release, assume we also want to create symlinks.
my $current_release = shift;

my $FTP_SPECIES_ROOT  = "/usr/local/ftp/pub/wormbase/species";
my $FTP_RELEASES_ROOT = "/usr/local/ftp/pub/wormbase/releases";

my @species  = glob("$FTP_SPECIES_ROOT/*") or die "$!";

my @releases;
if ($current_release) {
    @releases = glob("$FTP_RELEASES_ROOT/$current_release") or die "$!";
} else {
    @releases = glob("$FTP_RELEASES_ROOT/*") or die "$!";
}

foreach my $release_path (@releases) {
    next unless $release_path =~ /.*WS\d\d.*/;    
    my @species = glob("$release_path/species/*");

    my ($release) = ($release_path =~ /.*(WS\d\d\d).*/);

    # Where should the release notes go?
    # chdir "$FTP_SPECIES_ROOT";
    
    foreach my $species_path (@species) {
	next if $species_path =~ /README/;

	my ($species) = ($species_path =~ /.*\/(.*)/);

	# Create a symlink to each file in /species
	opendir DIR,"$species_path" or die "Couldn't open the dir: $!";
	while (my $file = readdir(DIR)) {
	    	    
	    # Create some directories. Probably already exist.
	    chdir "$FTP_SPECIES_ROOT/$species";
	    mkdir("gff");
	    mkdir("annotation");
	    mkdir("sequence");

	    chdir "$FTP_SPECIES_ROOT/$species/sequence";
	    mkdir("genomic");
	    mkdir("transcripts");
	    mkdir("protein");
	    
	    # GFF?
	    chdir "$FTP_SPECIES_ROOT/$species";
	    if ($file =~ /gff/) {
		chdir("gff") or die "$!";
		create_symlink("../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /genomic|sequence/) {
		chdir "$FTP_SPECIES_ROOT/$species/sequence/genomic" or die "$!";
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /transcripts/) {
		chdir "$FTP_SPECIES_ROOT/$species/sequence/transcripts" or die "$! $species";
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    } elsif ($file =~ /wormpep|protein/) {
		chdir "$FTP_SPECIES_ROOT/$species/sequence/protein" or die "$!";
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
		
	    # best_blast_hits isn't in the annotation/ folder
	    } elsif ($file =~ /best_blast/) {
		chdir "$FTP_SPECIES_ROOT/$species";
		mkdir("annotation");
		chdir("annotation");
		mkdir("best_blast_hits");
		chdir("best_blast_hits");
		create_symlink("../../../../releases/$release/species/$species/$file",$file,$release);
	    } else { }	   
	}
	
	# Annotations, but only those with the standard format.
#	chdir "$FTP_SPECIES_ROOT/$species";
	opendir DIR,"$species_path/annotation" or next;
	while (my $file = readdir(DIR)) {
	    next unless $file =~ /^$species/;
	    chdir "$FTP_SPECIES_ROOT/$species";

	    mkdir("annotation");
	    chdir("annotation");
	    
	    my ($description) = ($file =~ /$species\.WS\d\d\d\.(.*?)\..*/);
	    mkdir($description);
	    chdir($description);
	    create_symlink("../../../../releases/$release/species/$species/annotation/$file",$file,$release);
	}
    }
}
	



sub create_symlink {
    my ($target,$filename,$release) = @_;   
    symlink($target,$filename) or warn "$!";
    if ($current_release) {
	$filename =~ s/$release/current/;
	symlink($target,$filename) or warn "$!";
    }
}
