#!/usr/bin/perl

use strict;
use Ace;

my $usage = "$0 (<acedb_dir> | <acedb_host>:<port>) (include type <predicted | no_predicted | all>)";

my ($database, $include_type) = @ARGV;
$database or die "Usage: $usage\n";

use constant NA => 'N/A';

my $DB;
if ($database =~ /:/) {
        my ($host, $port) = split(":", $database);
        $DB = Ace->connect( -host => $host, -port => $port)
                or die "Cannot connect to host: $host, port: $port\n";
        } else {
                $DB = Ace->connect( -path => $database)
                or die "Cannot connect to database (directory): $database\n";
        }

print '# ' . join(' ',qw/WBInteractionID Interaction_type Citation Gene1-WBID Gene1-Molecular_name Gene1-CGC_name Gene2-WBID Gene2-Molecular_name Gene2-CGC_name .../) . "\n";

my @interactions = $DB->fetch(Interaction=>'*');
foreach my $interaction (@interactions) {
   print STDERR $interaction,"\n";
   my ($brief_citation,$db_field,$db_acc) = eval { $interaction->Paper->Brief_citation,$interaction->Paper->Database(2),$interaction->Paper->Database(3) };
   my $reference = "[$db_field:$db_acc] $brief_citation";
   my $interaction_type = eval { $interaction->Interaction_type };
   if ($include_type eq "no_predicted") {
       if ($interaction_type eq "Predicted_interaction") {next}
   } elsif ($include_type eq "predicted") {
       if ($interaction_type ne "Predicted_interaction") {next}
   }
   my @cols = ($interaction);
   push @cols,$interaction_type,$reference;
   foreach ($interaction->Interactor) {
      my ($interactor,$type) = $_->row;
      my $molecular_name = $interactor->Molecular_name || NA;
      my $cgc_name = $interactor->CGC_name || NA;
      push (@cols,$interactor,$molecular_name,$cgc_name)
    }
   print join("\t",@cols) . "\n";
}

exit 0;
