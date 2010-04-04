#!/usr/bin/perl

# Create an MD5 checksum

use strict;
use Digest::MD5;

my $file = shift;
die "Usage: $0 /path/to/file/filebase.tgz"  unless ($file); 


$file =~ /(.*)\/(.*).tgz/;
my $path = $1;
my $base = $2;

open(FILE, "$file") or die "Can't open '$file': $!";
binmode(FILE);
	
open OUT,">$path/$base.md5";
print OUT Digest::MD5->new->addfile(*FILE)->hexdigest, "  $file\n";

# Verify the checksum...
chdir($base);
my $result = `md5sum -c $path/$base.md5`;
die "Checksums do not match: packaging $file failed\n" if ($result =~ /failed/);
