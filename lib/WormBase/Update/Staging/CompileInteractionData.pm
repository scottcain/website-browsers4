package WormBase::Update::Staging::CompileInteractionData.pm;


use lib "/usr/local/wormbase/website/tharris/extlib";
use Ace;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile interaction data',
    );

has 'datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir   = join("/",$self->support_databases_dir,$release,'interaction');
    $self->_make_dir($datadir);
    return $datadir;
}

has 'dbh' => (
    is => 'ro',
    lazy_build => 1);

sub _build_dbh {
    my $self = shift;
    my $release = $self->release;
    my $acedb   = $self->acedb_root;
    my $dbh     = Ace->connect(-path => "$acedb/wormbase_$release") or $self->log->logdie("couldn't open ace:$!");
    return $dbh;
}

sub run {
    my $self = shift;
    my $datadir = $self->datadir;
    my $outfile = $datadir . "/compiled_interaction_data.txt";
    
    $self->log->info("creating compiled_interaction_data.txt");	
    $self->compile_interaction_data($outfile);   
    $self->log->debug("compile_interaction_data done");
}

sub compile_interaction_data {
	my $self = shift @_;
	my $outfile = shift @_;
	
	open OUTFILE, ">$outfile" or die "Cannot open gene_rnai_pheno_data_compile output file\n"; 

	my $class = 'Interaction';
	my $interactions = $self->dbh->fetch_many(-class => $class);
	my @objects;
	
	while(my $interaction= $interactions->next) {
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
		my $it;
		my $rnai;
		my $type;
		my $phenotype;
		my $phenotype_name;

		$it = $interaction->Interaction_type;
		$type = $it;
		$rnai = eval{$it->Interaction_RNAi->right;};
		$phenotype = eval {$it->Interaction_phenotype->right;};
		$phenotype_name = eval{$phenotype->Primary_name;};

		my @non_directional_interactors;
		my $effr;
		my $effr_name;
		my $effd;
		my $effd_name;
		my $interaction_vector;

		@non_directional_interactors = eval {$it->Non_directional->col;};
		
		if (@non_directional_interactors) {
			my @non_directinal_interactor_data;
			foreach my $non_directional_interactor (@non_directional_interactors) {
				my $ndi_name;
				$ndi_name = eval{$non_directional_interactor->CGC_name;};
				if (!($ndi_name)) {
				
					$ndi_name = eval{$effr->Sequence_name;};
				}
				push @non_directinal_interactor_data,  $non_directional_interactor . "#" . $ndi_name;
			}
			$effr = join "&" , @non_directinal_interactor_data;
			$effr_name = "";
			$effd = "";
			$effd_name = "";
			$interaction_vector = 'non_directional';
		}	
		else {
			my @effrs = eval{$it->Effector->col;};
			my @effds = eval{$it->Effected->col;};
			
			## effector data
			my @effector_data;
			
			foreach my $effector (@effrs) {
				my $effector_name;
				$effector_name = eval{$effector->CGC_name;};
			
				if (!($effector_name)){
					$effector_name = eval{$effector->Sequence_name;};
				}			
				push @effector_data, $effector . "#" . $effector_name;	
			}
			$effr = join "&" , @effector_data;
			$effr_name = "";
			
			## effected data
			my @effected_data;
			
			foreach my $effected (@effds) {
				my $effected_name;
				$effected_name = eval{$effected->CGC_name;};
				
				if (!($effected_name)){
					$effected_name = eval{$effected->Sequence_name;};
				}		
				
				push @effected_data, $effected . "#" . $effected_name;	
			}
			$effd = join "&" , @effected_data;
			$effd_name = "";
			$interaction_vector = 'eftr\-\>eftd';
		}
		
		print OUTFILE "$interaction\|$type\|$rnai\|$effr\|$effr_name\|$effd\|$effd_name\|$phenotype\|$interaction_vector\|$phenotype_name\n";
		# print "$interaction\|$type\|$rnai\|$effr\|$effr_name\|$effd\|$effd_name\|$phenotype\|$interaction_vector\|$phenotype_name\n";
		}
}

1;
