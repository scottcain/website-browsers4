#!/usr/bin/perl

# Parse the FTP site logs and create some simple stats

#Sun Mar  9 10:52:09 2014 [pid 3] [ftp] OK DOWNLOAD: Client "66.249.76.98", "/pub/wormbase/releases/WS205/species/p_pacificus/p_pacificus.WS205.cds_transcripts.fa.gz", 8054755 bytes, 21965.67Kbyte/sec

my %data;
my %files;

while (<>) {
    $_ =~ /.*DOWNLOAD: Client "(.*)", "(.*)",.*/;
    my $ip = $1;
    my $file = $2;
    push @{$data{$ip}},$file; 
    $files{$file}++;
}


print "Unique hosts: " . (scalar keys %data) . "\n";
foreach (keys %data) {
    print $_,"\n";
    foreach my $file (@{$data{$_}}) {
	print "\t$file\n";
    }
}

print "FILES SEEN\n";
foreach (sort { $files{$b} <=> $files{$a} } keys %files) {
	print "$_\t$files{$_}\n";
}
