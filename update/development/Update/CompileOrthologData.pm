package Update::CompileOrthologData;

use strict;
use base 'Update';
use Ace;

# The symbolic name of this step
sub step { return 'compiling ortholog_other data'; }

our $DB = Ace->connect(-host=>'localhost', -port=>2005) or die "Cannot connect to DB for get_all_ortholog_other_data\n"; 

sub run {

	my $self = shift;
	my $release = $self->release;
	my $last_gene = $self->last_gene;	
	
	my $support_db_dir = $self->support_dbs;
	my $datadir = $support_db_dir . "/$release/orthology";

	#print "$datadir\n";
	
	$self->get_all_ortholog_other_data($datadir, $last_gene);

}

sub last_gene { return shift->{last_gene}; };


sub get_all_ortholog_other_data {

	my $self = shift;
	my $datadir = shift;
	my $last_processed_gene = shift;
	
	my $gene_list = "gene_list.txt";
	my $ortholog_other_data_txt_file = "ortholog_other_data.txt";
	my $last_processed_gene_txt = "last_processed_gene.txt";
	
	open GENELIST, "< $datadir/$gene_list" or die "Cannot open $gene_list for getting orthologs\n";

	my $gene_id;
	
	## iterate down list to last entry processed
	
	if ($last_processed_gene) {
		while (!($gene_id eq $last_processed_gene)) {

			$gene_id = <GENELIST>;
			chomp $gene_id;
		} 
	}

	open OUT, ">> $datadir/$ortholog_other_data_txt_file" or die "Cannot open $datadir/$ortholog_other_data_txt_file\n"; 

	foreach my $gene_id (<GENELIST>) { #@objects_test_list 
	
		chomp $gene_id;
		
		my $gene = $DB->fetch(-class=>'Gene', -name=>$gene_id);
		print "processing\: $gene_id\n";
		
		my @ortholog_others;
		eval{ @ortholog_others = $gene->Ortholog_other;};
		
		foreach my $ortholog_other (@ortholog_others){
		
			my $method; 
		  	eval{$method = $ortholog_other->right(2);};
		  	my $protein_id;
			eval{$protein_id = $ortholog_other->DB_info->right(3);};
			my $db;
			eval{$db = $ortholog_other->DB_info->right;};
			my $fa;
			eval{$fa = "From_analysis";};
			my $species;
			eval{$species = $ortholog_other->Species;}; 
			print OUT "$gene\|$db\|$protein_id\|$species\|$fa\|$method\n";
        }
		
		system("echo $gene_id > $datadir/$last_processed_gene_txt");		
	}	
}
1;
