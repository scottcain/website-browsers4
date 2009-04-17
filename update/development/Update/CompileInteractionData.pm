package Update::CompileInteractionData; #


use base 'Update';
use strict;
use Ace;

sub step {return 'compile interaction data';}

sub run{
    my $self = @_;
    my $release = $self->release;
    
    ### interaction dir should have been created
    
    my $support_db_dir = $self->support_dbs;
    my $datadir = $support_db_dir."/$release/interaction";
	
    my $class = 'Interaction';

    # TH: This should NOT be directed to a production node
    my $DB = Ace->connect(-host=>'aceserver.cshl.org',-port=>2005);
    my $target = "compiled_interaction_data_test.txt"; ## 
    open OUT, ">$datadir/$target" or $self->logit->logdie("Cannot open the output file $target");
    # print "Ace connected\n";"Cannot open the output file $target"
    
    # my $aql_query = "select all class $class limit 10";
    # my @objects_full_list = $DB->aql($aql_query);
    my @objects_full_list = $DB->fetch(-class=>$class,-count=>100, -offset=> 250);
    my @objects = @objects_full_list;
    
    
    # my $objects = @objects_full_list[0 .. 10];
    # foreach my $interaction (@$objects){
    
    foreach my $interaction(@objects){   ## $object 
	eval{
	    # my $interaction = shift (@{$object}); #
	    my $it = $interaction->Interaction_type;
	    my $type = $it;
	    my $rnai = $it->RNAi;
	    my $effr = $it->Effector->right;
	    my $effr_name = $effr->CGC_name;
	    if (!($effr_name)){
		$effr_name = $effr->Sequence_name
		}
	    my $effd = $it->Effected->right;
	    my $effd_name = $effd->CGC_name;
	    if (!($effd_name)){
		$effd_name = $effd->Sequence_name
		}
	    my $phenotype = $it->Interaction_phenotype;
	    print OUT "$interaction\|$type\|$rnai\|$effr\&$effr_name\|$effd\&$effd_name\|$phenotype\n";
	}	
    }
}

1;
