package Update::CompileInteractionData;

use strict;
use base 'Update';
use Ace;

our $DB = Ace->connect(-host=>'localhost', -port=>2005);

# The symbolic name of this step

sub step { return 'compiling interaction data'; }

sub run {

	my $self = shift;
	my $release = $self->release;
	
	## directories
	
	my $support_db_dir = $self->support_dbs;	
	my $datadir = $support_db_dir . "/$release/interaction";
	my $outfile = $datadir . "/compiled_interaction_data.txt";

	## subroutine call(s) 
	
	$self->compile_interaction_data($outfile);

}



## subroutines

sub compile_interaction_data {

	my $self = shift @_;
	my $outfile = shift @_;
	
	open OUTFILE, ">$outfile" or die "Cannot open gene_rnai_pheno_data_compile output file\n"; 

	my $class = 'Interaction';
	my $DB = Ace->connect(-host=>'localhost',-port=>2005);  # 'aceserver.cshl.org'
	
	
	#my @interactions = $DB->fetch(-class=>$class, -count=>1000);
	my @interactions = $DB->fetch(-class=>$class);
	
	my @objects;
	
	
	foreach my $interaction (@interactions) {
		#print "$interaction\n";
		my $int_type = $interaction->Interaction_type;
		if ($int_type =~ /predicted/i) {
		
			my $log_likelihood_score = $interaction->Log_likelihood_score;
		
			if ($log_likelihood_score >= 1.5) {
		
				push @objects, $interaction;
			} else {
		
				next;
			}
		} else {
	
			push @objects, $interaction;
		}
	
	} ## end foreach my $interaction 
	
	
	foreach my $interaction (@objects){  
	
		eval {
		# my $interaction = shift (@{$interaction_ref});
		my $it = $interaction->Interaction_type;
		my $type = $it;
		my $rnai = $it->RNAi;
		
		my @non_directional_interactors;
		my $effr;
		my $effr_name;
		my $effd;
		my $effd_name;
		my $interaction_vector;
		
		eval {
			@non_directional_interactors = $it->Non_directional->col;
		};
		
		if (@non_directional_interactors) {
			$effr = shift @non_directional_interactors;
			$effr_name = $effr->CGC_name;
		if (!($effr_name)){
			$effr_name = $effr->Sequence_name
		}
			$effd = shift @non_directional_interactors;
			$effd_name = $effd->CGC_name;
		if (!($effd_name)){
			$effd_name = $effd->Sequence_name
		}
		
		$interaction_vector = 'non_directional';
		
		}
		else {
			$effr = $it->Effector->right;
			$effr_name = $effr->CGC_name;
		if (!($effr_name)){
			$effr_name = $effr->Sequence_name
		}
			$effd = $it->Effected->right;
			$effd_name = $effd->CGC_name;
		if (!($effd_name)){
			$effd_name = $effd->Sequence_name
		}
		
		
		$interaction_vector = 'eftr\-\>eftd';
		
		}
		
		my $phenotype = $it->Interaction_phenotype;
	
	
		print OUTFILE "$interaction\|$type\|$rnai\|$effr\|$effr_name\|$effd\|$effd_name\|$phenotype\|$interaction_vector\n";
		}
}





}


1;
