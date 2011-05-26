#!/usr/bin/perl

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use Getopt::Long;
use Ace;
use strict;

my ($path,$host,$port,$species);
GetOptions(
           "path=s"      => \$path,
	   "host=s"      => \$host,
	   "port=i"      => \$port,
           "species=s"   => \$species,
	  );

($path || ($host && $port)) || die <<USAGE;

Usage: $0 [options]
   
   --path  Path to acedb database
   OR
   --host      hostname for acedb server
   --port      port number (for specified host)

  Optional:
   --species    The species to constrain the dump;

USAGE
    ;

# Establish a connection to the database.
my $dbh = $path
    ? Ace->connect(-path => $path )
    : Ace->connect(-port => $port, -host => $host) or die $!;

my $date = `date +%Y-%m-%d`;
chomp $date;


my ($g,$species_alone) = split("_",$species);
$g = uc($g);

#exit 0 unless $species_alone eq 'elegans';

use constant NA => 'N/A';

print "# $g. $species_alone orthologs\n";
print "# WormBase version: " . $dbh->version . "\n";
print "# Generated: $date\n";
print '# File is in record format with records separated by "=\n"' . "\n";
print "#      Sample Record\n"; 
print '#      WBGeneID \t PublicName \n' . "\n";
print '#      Species \t Ortholog \t MethodsUsedToAssignOrtholog \n' . "\n";
print '# BEGIN CONTENTS' . "\n";
print "=\n";

my $i = $dbh->fetch_many(-query=>qq{find Gene Species=$g*$species_alone});
while (my $gene = $i->next) {
    next unless $gene->Species =~ /$species_alone/;

    my %orthologs = ();   
    
    # Nematode orthologs
    foreach ($gene->Ortholog) {
	my $methods  = join('; ',map { "$_" } eval { $_->right(2)->col }) ;
	$orthologs{$_->Species} = [ $_,$methods ];
    }

    foreach ($gene->Ortholog_other) {
	my $methods  = join('; ',map { "$_" } eval { $_->right->col });
	$orthologs{$_->Species} = [ $_,$methods ];
    }

    print join("\t",$gene,$gene->Public_name),"\n";
    
    foreach (sort keys %orthologs) {
	my ($ortholog,$methods) = @{$orthologs{$_}};
	print join("\t",$_,$ortholog,$methods),"\n";
    }
    print "=\n";
}

exit 0;
