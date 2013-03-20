#!/usr/bin/perl

use strict;
use Ace;

my $usage = "$0 (<acedb_dir> | <acedb_host>:<port>) [gene_list_file]";

my ($database, $file) = @ARGV;
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

print '# ' . join(' ',qw/WBInteractionID Gene1-WBID Gene1-Molecular_name Gene1-CGC_name Gene2-WBID 
Gene2-Molecular_name Gene2-CGC_name Interaction_type Brief_citation/) . "\n";

my @interactions = $DB->fetch(Interaction=>'*');

foreach my $interaction (@interactions) {
    print STDERR $interaction,"\n";

    my $interaction_type = $interaction->Interaction_type;
    my $subtype = ($interaction_type =~ /Genetic|Regulatory/) ? $interaction_type->right : NA;
    my $role;
    foreach my $interactor_type ($interaction->Interactor) {		
	my $count = 0;
	my @cols = ($interaction,$interaction_type,$subtype,);
	foreach my $interactor ($interactor_type->col) {
	    my @interactors = $interactor_type->col;
	 
	    my @tags = eval { $interactors[$count++]->col };

	    my %info;
	    $info{obj} = $interactor;
	    my (@effectors,@effected);
	    if ( @tags ) {
		map { $info{"$_"} = $_->at; } @tags;
		if ("$interactor_type" eq 'Interactor_overlapping_gene') {
		    $role = $info{Interactor_type};
#		    if ($role && $role =~ /Effector|.*regulator/) {     push @effectors, $interactor }
#		    elsif ($role && $role =~ /Effected|.*regulated/)  { push @effected, $interactor }
#		    else { }
#		    else { push @others, $interactor }
		} 
	    }
	    my $molecular_name = $interactor->Molecular_name || NA;
	    my $cgc_name       = $interactor->CGC_name       || NA;
	    push (@cols,$interactor,$molecular_name,$cgc_name)
	}
	
	my $reference = eval { $interaction->Paper->Brief_citation };
	push @cols,$role,$reference;
	print join("\t",@cols) . "\n";
    }
}

exit 0;






