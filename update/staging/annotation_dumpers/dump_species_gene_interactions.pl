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

# Currently no species tag for interactions.
exit 0 unless $species_alone eq 'elegans';

use constant NA => 'N/A';

print "# $g. $species_alone gene interactions\n";
print "# WormBase version: " . $dbh->version . "\n";
print "# Generated: $date\n";
print '# ' . join("\t",qw/WBInteractionID Interaction_type Interaction_subtype Summary Citation Interactor1 Common-name Role1 Interactor2 Common-name Role2 .../),"\n";

# my @interactions = $dbh->fetch(Interaction=>'*');
my @interactions = $dbh->fetch(-query=>'find Interaction WBInteraction????????? ! Interaction_type = Predicted');   #ignore objects with invalid name and Predicted

foreach my $interaction (@interactions) {
    my ($brief_citation,$db_field,$db_acc) = eval { $interaction->Paper->Brief_citation,$interaction->Paper->Database(2),$interaction->Paper->Database(3) };
    my $reference = "[$db_field:$db_acc] $brief_citation";
    my $interaction_type = $interaction->Interaction_type;
    my $subtype = ($interaction_type =~ /Genetic|Regulatory/) ? $interaction_type->right : NA;
#    exclude negative results
	if ($subtype =~ /No_interaction/) {next}
	if ($interaction->Regulation_result =~ /Does_not_regulate/) {next}
	
    my @cols;
	my @cols = ($interaction,$interaction_type,$subtype,);
	my $summary = eval {$interaction->Interaction_summary};
	push @cols,$summary;
	my $reference = eval { $interaction->Paper->Brief_citation };
	push @cols,$reference;

    foreach my $interactor_type ($interaction->Interactor) {		# e.g. PCR_inteactor, Interactor_overlapping_gene
		my $role = '';
		my $count = 0;
		foreach my $interactor ($interactor_type->col) {
			my @interactors = $interactor_type->col;
			my @tags = eval { $interactors[$count++]->col };     # Interactor_info
			my %info;
			$info{obj} = $interactor;
			if ( @tags ) {
				map { $info{"$_"} = $_->at; } @tags;
				if ($interactor_type =~ /Other_regulator|Interactor_overlapping_gene|Molecule_regulator|Other_regulated|Rearrangement/) {		# Exclude those that have been translated to Gene
					$role = $info{Interactor_type};
					my @interactor_names;
					my $public_name = eval {$interactor->Public_name} || NA;
					push (@interactor_names,$interactor,$public_name);
					push (@cols,@interactor_names,$role);
				}
			}
		}
	}	

	print join("\t",@cols) . "\n";
	
}


exit 1;
