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

$path || die <<USAGE;

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

# Currently no species tag for interactions.
exit 0 unless $species_alone eq 'elegans';

use constant NA => 'N/A';

print "# $species gene interactions\n";
print "# WormBase version: " . $dbh->version;
print "# Generated: $date\n";
print '# ' . join('\t',qw/WBInteractionID Interaction_type Citation Gene1-WBID Gene1-Molecular_name Gene1-CGC_name Gene2-WBID Gene2-Molecular_name Gene2-CGC_name .../),"\n";

my @interactions = $dbh->fetch(Interaction=>'*');
foreach my $interaction (@interactions) {
#    print STDERR $interaction,"\n";

    my ($brief_citation,$db_field,$db_acc) = eval { $interaction->Paper->Brief_citation,$interaction->Paper->Database(2),$interaction->Paper->Database(3) };
    my $reference = "[$db_field:$db_acc] $brief_citation";
    my $interaction_type = $interaction->Interaction_type;
    my @cols;
    push @cols,$interaction,$interaction_type,$reference;
    foreach ($interaction->Interactor) {
	my ($interactor,$type) = $_->row;

#    if ($include_type eq "no_predicted") {
#	if ($interaction_type eq "Predicted_interaction") {next}
#    } elsif ($include_type eq "predicted") {
#	if ($interaction_type ne "Predicted_interaction") {next}
#    }
	my $molecular_name = $interactor->Molecular_name || NA;
	my $cgc_name = $interactor->CGC_name || NA;
	push (@cols,$interactor,$molecular_name,$cgc_name)
    }
    print join("\t",@cols) . "\n";
}

exit 1;
