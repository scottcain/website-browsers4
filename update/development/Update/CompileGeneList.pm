package Update::CompileGeneList;

use strict;
use Ace;
use base 'Update';

our $DB = Ace->connect(-host=>'localhost', -port=>2005) or die "Cannot connect to DB for get_all_ortholog_other_data\n"; 
# The symbolic name of this step
sub step { return 'compiling list of genes with ortholog_other data'; }

sub run {

	my $self = shift;
	my $release = $self->release;
	my $support_db_dir = $self->support_dbs;	
	my $datadir = $support_db_dir . "/$release/orthology";
	
	$self->get_genes_with_orthologs($datadir);
}


sub get_genes_with_orthologs {

		my $self = shift @_;
		my $datadir = shift @_;
		
		my $class = 'Gene';
		my $tag = 'Ortholog_other';
		my $gene_list = "gene_list.txt";


		open GENELIST, "> $datadir/$gene_list" or die "Cannot open $datadir/$gene_list\n";

		my @genes = $DB->fetch(-class=>$class); ##, -count =>10, -offset=>1090
		foreach my $gene (@genes){

		    my @oo = $gene->Ortholog_other;
		    if (@oo) {
			
				print GENELIST "$gene\n";

		    } else {

			next;

		    }
		}
		
		close GENELIST;
}


1;
