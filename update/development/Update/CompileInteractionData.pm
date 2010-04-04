package Update::CompileInteractionData; #

use base 'Update';
use strict;
use Ace;

our $support_db_dir;
our $datadir;
our $interaction_data_file;


sub step {return 'compile interaction data';}

sub run{

    my $self = shift @_;
    my $release = $self->release;
    
    ### interaction dir should have been created
    
    $support_db_dir = $self->support_dbs;
    $datadir = $support_db_dir."/$release/interaction";
	$interaction_data_file = $datadir . "\/compiled_interaction_data.txt";
	print "Compiling interaction data\n";
	$self->compile_interaction_data();

}

sub compile_interaction_data {

my $class = 'Interaction';
my $DB = Ace->connect(-host=>'localhost',-port=>2005);  # 'aceserver.cshl.org'

my @interactions = $DB->fetch(-class=>$class);

my @objects;

open OUTFILE, ">$interaction_data_file" or die "Cannot open interaction data output file\n";

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


} ## end foreach



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
