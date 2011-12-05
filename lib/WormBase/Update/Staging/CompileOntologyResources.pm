package WormBase::Update::Staging::CompileOntologyResources;

use lib "/usr/local/wormbase/website/tharris/extlib";
use DB_File;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile ontology resources',
    );

my %ontology2name = (go => 'gene',
		     po => 'phenotype',
		     ao => 'anatomy');

# Filenames used by this module. Eeeks.
# All will be found in databases/WSXXX/ontology.
has 'search_data_preprocessed_file' => ( is => 'ro' , default => 'search_data_preprocessed.txt');
has 'go_obo_file'                   => ( is => 'ro' , default => 'gene_ontology.%s.obo'       );
has 'go_assoc_file'                 => ( is => 'ro' , default => 'gene_association.%s.wb.ce'  );
has 'ao_obo_file'                   => ( is => 'ro' , default => 'anatomy_ontology.%s.obo'    );
has 'ao_assoc_file'                 => ( is => 'ro' , default => 'anatomy_association.%s.wb'  );
has 'po_obo_file'                   => ( is => 'ro' , default => 'phenotype_ontology.%s.obo' );
has 'po_assoc_file'                 => ( is => 'ro' , default => 'phenotype_association.%s.wb');
has 'id2parents_file'               => ( is => 'ro' , default => 'id2parents.txt'             );
has 'parent2ids_file'               => ( is => 'ro' , default => 'parent2ids.txt'             );
has 'id2name_file'                  => ( is => 'ro' , default => 'id2name.txt'                );
has 'name2id_file'                  => ( is => 'ro' , default => 'name2id.txt'                );
has 'id2association_counts_file'    => ( is => 'ro' , default => 'id2association_counts.txt'  ); 
has 'id2total_association_file'    => ( is => 'ro' , default => 'id2total_associations.txt'  ); 


has 'datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir   = join("/",$self->support_databases_dir,$release,'ontology');
    $self->_make_dir($datadir);
    return $datadir;
}

has 'gene_datadir' => (
    is => 'ro',
    lazy_build => 1);

sub _build_gene_datadir {
    my $self = shift;
    my $release = $self->release;
    my $gene_datadir   = join("/",$self->support_databases_dir,$release,'gene');
    return $gene_datadir;
}

has 'dbh' => (
    is => 'ro',
    lazy_build => 1);

sub _build_dbh {
    my $self = shift;
    my $release = $self->release;
    my $acedb   = $self->acedb_root;
    my $dbh     = Ace->connect(-path => "$acedb/wormbase_$release") or $self->log->warn("couldn't open ace:$!");
    $dbh = Ace->connect(-host => 'localhost',-port => 2005) unless $dbh;    
    return $dbh;
}


sub run {
    my $self = shift;
    my $release = $self->release;
    
    # The ontology directory should already exist. Let's make certain.    
    my $datadir = $self->support_databases_dir. "/$release/ontology";

    $self->copy_ontology();   

#    # Iterate over each ontology
   foreach my $ontology (keys %ontology2name) {	

	# compile search_data.txt  
	$self->compile_search_data($ontology);
	
	# compile id2parents relationships
	$self->compile_ontology_relationships($ontology,1);
	
	# compile parent2ids relationships
	$self->compile_ontology_relationships($ontology,2);
    }
   

    $self->parse_search_data(0,1,$self->id2name_file);
    $self->parse_search_data(1,0,$self->name2id_file);
    $self->parse_search_data(0,5,$self->id2association_counts_file);    
    $self->clean_up_search_data();
    $self->get_geneid2go_ids();
    $self->get_pheno_gene_data_not();
    $self->get_pheno_gene_data();
    $self->get_pheno_rnai_data();
    $self->get_pheno_variation_data();
    $self->get_pheno_rnai_data(1);
    $self->get_pheno_variation_data(1);
    $self->get_pheno_xgene_data();

    
    my $bin_path = $self->bin_path . "/../helpers/";
    my $cmd = "get_cumulative_association_counts.pl $release";
    $self->system_call("$bin_path/$cmd",
		       "$bin_path/$cmd");
    
    $self->get_cumulative_association_counts('id2total_associations.txt');
    $self->log->info("crazy gene page compiles complete");
}


sub copy_ontology {
    my $self = shift;
    my $release = $self->release;
    my $source = join("/",$self->ftp_releases_dir,$release,'ONTOLOGY');
    my $target = join("/",$self->support_databases_dir,$release,'ontology');
    $self->system_call("cp $source/* $target",
		       "copying ontology");

}



####################################################################################################
#
#  Takes obo and association files and creates 
#  a table of annotations for terms in a given ontology
#  syntax make_sample_file <obo_file_name> <namespace> <association_file_name>
#
####################################################################################################

sub compile_search_data {
    my ($self,$type,) = @_;
    $self->log->info("compiling search_data.txt for $type");
    
    my $obo_tag   = $type . '_obo_file';
    my $assoc_tag = $type . '_assoc_file';

    my $datadir = $self->datadir;
    my $release = $self->release;
    my $obo_file_name         = join("/",$datadir,sprintf($self->$obo_tag,$release));
    my $association_file_name = join("/",$datadir,sprintf($self->$assoc_tag,$release));
    
    open HTML, "< $obo_file_name" or $self->log->logdie("Cannot open the protein file: $obo_file_name; $!");
 
   my $target = join("/",$datadir,$self->search_data_preprocessed_file);
    open OUT,">>$target" or $self->log->logdie("Cannot open the output file $target");
    
    my $id;
    my $term;
    my $def;
    my $syn;
    my $namespace = $ontology2name{$type};
    my $discard;
    my $annotation_count;
    my @synonyms;
    
    foreach my $obo_file_line (<HTML>) {
	chomp $obo_file_line;
	$annotation_count = 0;
	
	if($obo_file_line =~ m/^id\:/){
	    #print "$obo_file_line\n";
	    ($discard, $id) = split '\: ', $obo_file_line;
	    #print "$discard\n";
	    chomp $id;
	    #print "$id\n";
	} elsif ($obo_file_line =~ m/^name\:/) {
	    ($discard, $term) = split '\: ', $obo_file_line;
	    chomp $term;
	} elsif ($obo_file_line =~ m/^namespace\:/) {
	    ($discard, $namespace) = split '\: ', $obo_file_line;
	    chomp $namespace;
	} elsif ($obo_file_line =~ m/^def\:/) {
	    ($discard, $def) = split '\: ', $obo_file_line;
	    $def =~ s/\[.*\]//g;
	    $def=~ s/\"//g;
	    chomp $def;
	} elsif ($obo_file_line =~ m/^synonym\:/) {
	    ($discard, $syn) = split '\"', $obo_file_line;
	    $syn =~ s/lineage name\: //;
	    chomp($syn);
	    push @synonyms,$syn;
	} elsif ($obo_file_line =~ m/\[Term\]/) {
	    $annotation_count = `grep -c \'$id\' $association_file_name`;
	    my $synonym_list = join '-&-',@synonyms;
	    print OUT "$id\|$term\|$def\|$namespace\|$synonym_list\|$annotation_count\n";
	    @synonyms = ();
	    #print "$id\|$term\|$def\|$namespace\|$annotation_count\n";
	} else {
	    next;
	}
    }
    close OUT;
}


##############################################################################################
# parses the obo files and gets parent-child relationships between terms in the the ontology
# syntax: ontology_relations.pl <obo_file_name> and creates a two DB_File files 
# using term ids as keys and  contains two listings, one of their parents, the other of the children.
# NB: abstract to work with specificid ontologies
###############################################################################################

sub compile_ontology_relationships {
    my ($self,$type,$format) = @_;
    $self->log->info("compiling ontology relationships for $type");
    
    my $obo_tag   = $type . '_obo_file';
    my $assoc_tag = $type . '_assoc_file';

    my $datadir = $self->datadir;
    my $release = $self->release;
    my $obo_file_name         = join("/",$datadir,sprintf($self->$obo_tag,$release));
    my $association_file_name = join("/",$datadir,sprintf($self->$assoc_tag,$release));

    my $base_output = ($format == 1) ? $self->id2parents_file : $self->parent2ids_file;
    my $output = join("/",$datadir,$base_output);

    open HTML, "< $obo_file_name" or $self->log->logdie("Cannot open the protein file: $obo_file_name");
    open OUT,">>$output" or $self->log->logdie("Cannot open the output file: $output $!");
    
    my $id;
    my $parent;
    my %id2parent;
    my %parent2id;
    my $discard;

    # system ('rm ./id2parents.dat');
    # system ('rm ./parent2ids.dat');
    
    foreach my $obo_file_line (<HTML>) {
	chomp $obo_file_line;
	my $annotation_count = 0;
	
	if($obo_file_line =~ m/^id\:/){
	    # print "$obo_file_line\n";
	    ($discard, $id) = split '\: ', $obo_file_line;
	    #print "$discard\n";
	    chomp $id;
	    # print "inside\:$id\n";
	    undef $discard;
	}
	
	# print "outside\:$id\n";
	
	if($obo_file_line =~ m/^is_a\:/){
	    # print "$obo_file_line\n";
	    my ($discard, $parent) = split '\: ', $obo_file_line;
	    #print "$discard\n";
	    chomp $parent;
	    # print "$id\n";
	    ($parent, $discard) = split ' ! ', $parent;
	    # print "is_a\&$parent\<\-$id\n";
	    $parent = "is_a\&".$parent;
	    $parent2id{$parent}{$id} = 1;
	    $id2parent{$id}{$parent} = 1;	    
	}
	
 	if($obo_file_line =~ m/^relationship\:/){
	    # print "$obo_file_line\n";
	    my ($discard, $parent) = split '\: ',$obo_file_line;
	    #print "$discard\n";
	    chomp $parent;
	    $parent =~ s/ /&/;
	    ($parent, $discard) = split ' ! ',$parent;
	    # print "$parent\<\-$id\n";
	    $parent2id{$parent}{$id} = 1;
	    $id2parent{$id}{$parent} = 1;
	} elsif($obo_file_line =~ m/\[Term\]/){
	    # print "\n\*TERM\*\n";
	    undef $id;
	    undef $parent;
	} else {
	    next;
	}	
    }
    
    my %id2parents;
    my %parent2ids;
    
# tie (%id2parents, 'DB_File', 'id2parents.dat') or die;
# tie (%parent2ids, 'DB_File', 'parent2ids.dat') or die;
    
    if ($format == 1) {
	foreach my $term (keys %id2parent){
	    print OUT "$term\=\>";
	    my @term_parents = (keys %{$id2parent{$term}});
	    my $term_parent_list = join '|', @term_parents;
	    print OUT "$term_parent_list";
	    print OUT "\n";
	    $id2parents{$term} = $term_parent_list;
	}
    } elsif ($format == 2) {
	foreach my $term (keys %parent2id) {
	    my ($discard,$parent_term) = split '&',$term;
	    print OUT "$parent_term\=\>";
	    my @term_children = (keys %{$parent2id{$term}});
	    my $term_children_list = join '|', @term_children;
	    print OUT "$term_children_list";
	    print OUT "\n";
	    $parent2ids{$parent_term} = $term_children_list;
	}
    }
    close OUT;
}

sub parse_search_data {
    my ($self,$index_1,$index_2,$output_file) = @_;
    
    my $output = join("/",$self->datadir,$output_file);
    $self->log->info("parsing search data to $output");

    my $datafile = join("/",$self->datadir,$self->search_data_preprocessed_file);
    open OUT, ">$output" or $self->log->logdie("Cannot open the output file: $output $!");
    open FILE, "< /$datafile" or $self->log->logdie("Cannot open $datafile");
    
    foreach my $line (<FILE>){
	if ($line =~ m/./) {
	    chomp $line;
	    # print "$line\n";
	    my @line_elements = split /\|/,$line;
	    print OUT "$line_elements[$index_1]\=\>$line_elements[$index_2]\n"; 	
	} else{
	    next;
	}
    }
}

# Was: helpers/clean_up_search_data.pl
sub clean_up_search_data {
    my $self = shift;
    my $release = $self->release;
    my $datadir = $self->datadir;

    my $input = join("/",$datadir,$self->search_data_preprocessed_file);
    my $output = join("/",$datadir,'search_data.txt');
    open IN,$input or $self->log->logdie("Couldn't open $input for reading");
    open OUT,">$output" or $self->log->logdie("COuldn't open $output for writing");

    foreach my $line (<IN>) {	
	chomp $line;
	my @line_elements = split /\|/, $line;
	$line_elements[1] =~ s/\_/ /g;
	$line_elements[4] =~ s/\_/ /g;
	my $new_line = join "|", @line_elements;	
	print OUT "$new_line\n";
    }
    close IN;
    close OUT;
}

sub get_cumulative_association_counts{

	my $self = shift;
	my $outfile = shift;
	my $data_directory = $self->datadir;
	
	my %id2parents = $self->build_hash($data_directory . '/' . $self->id2parents_file);
	my %id2name = $self->build_hash($data_directory. '/' . $self->id2name_file);
	my %parent2ids = $self->build_hash($data_directory. '/' . $self->parent2ids_file);
	my %id2association_counts = $self->build_hash($data_directory . '/' . $self->id2association_counts_file);
	
	my @ids = keys %id2name;
	
	open OUT, ">$data_directory/$outfile" or $self->log->logdie("Cannot open output file");
	foreach my $term_id (@ids) {
	
		my @path_array = ($term_id); ## 
		my @paths = $self->call_list_paths(\@path_array,\%id2parents,\%id2name,\%parent2ids,\%id2association_counts);
		my %descendants; 
	
		foreach my $path (@paths) {
			my @descendants = split '%', $path;
			foreach my $descendant (@descendants) {
				$descendants{$descendant} = 1;	
			}
		}
		
		my $total_count = 0;
		my @descendants = keys %descendants;
		shift  @descendants;
		foreach my $descendant (@descendants) {
			# print "DESC\:$descendant\:$id2association_counts{$descendant}\:$total_count\n";	
			$total_count = $total_count + $id2association_counts{$descendant};	
		}
	
		print OUT "$term_id\=\>$total_count\n";
	
	}
}

sub get_geneid2go_ids {  

	my $self = shift;
	my $DB = $self->dbh;
	my @genes = $DB->fetch(-class =>'Gene'); ## ,-count=>10,-offset =>500
	my $datadir = $self->datadir;
	my %go_id2gene_id;
	my %go_id2type;
	my %gene_id2name;
	
	open BP, ">$datadir/go_bp_id2gene_id.txt" or $self->log->logdie("Can't open bp");
	open MF, ">$datadir/go_mf_id2gene_id.txt" or $self->log->logdie("Can't open bp");
	open CC, ">$datadir/go_cc_id2gene_id.txt" or $self->log->logdie("Can't open bp");
	
	foreach my $gene (@genes) {
		my $gene_name = public_name($gene);
		$gene_id2name{$gene} = $gene_name; 
		my @go_terms = $gene->GO_Term;
		
		foreach my $go_term (@go_terms) {	
			if (!($go_id2type{$go_term})) {
				$go_id2type{$go_term} = $go_term->Type;
			}
			$go_id2gene_id{$go_term}{$gene} = 1;	
		}	
	}

	foreach my $go_term (keys %go_id2gene_id) {
		my $gene_ids = $go_id2gene_id{$go_term};
		my @gene_names = map {$_ = $gene_id2name{$_}} (keys %$gene_ids);
		
		if($go_id2type{$go_term}=~ m/biological/i) {		
			print BP "$go_term\=\>@gene_names\n"; ##$gene_id2name{$gene_id}
		}
		
		elsif ($go_id2type{$go_term}=~ m/function/i) {
			print MF "$go_term\=\>@gene_names\n";	##$gene_id2name{$gene_id}
		}
		else {
			print CC "$go_term\=\>@gene_names\n";	##$gene_id2name{$gene_id}
		}
	}
}


sub get_pheno_gene_data_not{ 

	my $self = shift;
	my %pheno_gene;
	my %genes;
	my %gene_id2name;
	my $DB = $self->dbh;
	my $indir = $self->gene_datadir;
	my $outdir = $self->datadir;
	
	open IN_XGENE, "<$indir/gene_xgene_pheno.txt" or $self->log->logdie("Can't open in file $indir/gene_xgene_pheno.txt");
	open IN_VAR,"<$indir/variation_data.txt" or $self->log->logdie("Can't open in file $indir/variation_data.txt");
	open IN_RNAi, "<$indir/gene_rnai_pheno.txt" or $self->log->logdie("Can't open in file $indir/gene_rnai_pheno.txt");
	open OUT, ">$outdir/pheno2gene_names_not.txt" or $self->log->logdie("Can't open out file $outdir/pheno2gene_names_not.txt");
	
	system ("echo 'fetching xgene related data'");
	
	while (<IN_XGENE>) {
		my ($gene,$xgene,$pheno,$not) = split /\|/,$_;
		if(!($not)) {
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;
		}
	}
	
	system ("echo 'fetching variation related data'");
	
	while (<IN_VAR>) {
		my ($gene,$var,$pheno,$not,$seqd) = split /\|/,$_;
		if(!($not)) {			
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;
		}
	}
	
	system ("echo 'fetching RNAi related data'");
	
	while (<IN_RNAi>) {
		my ($gene,$rnai,$pheno,$not) = split /\|/,$_;
		if(!($not)) {
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;
		}
	}

	system ("echo 'getting gene names'");
	
	foreach my $gene_id (keys %genes) {
		my $gene_obj = $DB->fetch(-class=>'Gene',-name=>$gene_id);
		my $gene_cgc = $gene_obj->CGC_name;
		my $gene_seq = $gene_obj->Sequence_name;
		$gene_id2name{$gene_id} = $gene_seq;
		$gene_id2name{$gene_id} = $gene_cgc;
	}
	
	system ("echo 'printing data'");
	
	foreach my $phenotype (keys %pheno_gene) {
	
		my $genes_ar = $pheno_gene{$phenotype};
		my @genes = keys %$genes_ar;
		my @gene_names = map {$_ = $gene_id2name{$_}} @genes;
		
		print OUT "$phenotype\=\>@gene_names\n";
	}
	system ("echo 'OK'");
	
}

sub get_pheno_gene_data{
	my $self = shift;
	my $DB = $self->dbh;
	my %pheno_gene;
	my %genes;
	my %gene_id2name;
	my $indir = $self->gene_datadir;
	my $outdir = $self->datadir;
	
	open IN_XGENE, "<$indir/gene_xgene_pheno.txt" or $self->log->logdie("Can't open xgene in file");
	open IN_VAR,"<$indir/variation_data.txt" or $self->log->logdie("Can't open variation in file");
	open IN_RNAi, "<$indir/gene_rnai_pheno.txt" or $self->log->logdie("Can't open rnai in file");
	open OUT, ">$outdir/pheno2gene_names.txt" or $self->log->logdie("Can't open out file");
	
	system ("echo 'fetching xgene related data'");
	
	while (<IN_XGENE>) {
		my ($gene,$xgene,$pheno,$not) = split /\|/,$_;
		if($not) {
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;	
		}
	}
	system ("echo 'fetching variation related data'");
	
	while (<IN_VAR>) {
		my ($gene,$var,$pheno,$not,$seqd) = split /\|/,$_;
		if($not) {
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;
		}
	}
	system ("echo 'fetching RNAi related data'");
	
	while (<IN_RNAi>) {
		my ($gene,$rnai,$pheno,$not) = split /\|/,$_;
		if($not) {	
			next;
		}
		else {
			$pheno_gene{$pheno}{$gene} = 1;
			$genes{$gene} = 1;
		}
	}
	system ("echo 'getting gene names'");
	
	foreach my $gene_id (keys %genes) {
			my $gene_obj = $DB->fetch(-class=>'Gene',-name=>$gene_id);
			my $gene_cgc = $gene_obj->CGC_name;
			my $gene_seq = $gene_obj->Sequence_name;
			$gene_id2name{$gene_id} = $gene_seq;
			$gene_id2name{$gene_id} = $gene_cgc;
	}
	system ("echo 'printing data'");
	
	foreach my $phenotype (keys %pheno_gene) {
		my $genes_ar = $pheno_gene{$phenotype};
		my @genes = keys %$genes_ar;
		my @gene_names = map {$_ = $gene_id2name{$_}} @genes;
		
		print OUT "$phenotype\=\>@gene_names\n";
	}
	system ("echo 'OK'");
}

sub get_pheno_rnai_data{ 

	my $self = shift;
	my $nay = shift;
	my 	%pheno_rnai;
	my $indir = $self->gene_datadir;
	my $outdir = $self->datadir;

	my $outfile = "pheno2rnais.txt";
	
	if ($nay) {
		$outfile = "pheno2rnais_not.txt";
	}
	
	open IN, "<$indir/gene_rnai_pheno.txt" or $self->log->logdie("Can't open infile");
	open OUT, ">$outdir/$outfile" or $self->log->logdie("Can't open outfile"); 

	while (<IN>) {	
		my ($gene,$rnai,$pheno,$not) = split /\|/,$_;
		if ($nay) {
			if($not =~ m/not/i) {
				$pheno_rnai{$pheno}{$rnai} = 1;
			}
			else {
				next;
			}
		}
		else {
			if ($not =~ m/not/i) {
				next;
			}
			else {
				$pheno_rnai{$pheno}{$rnai} = 1;
			}
		}
	}
	
	foreach my $phenotype (keys %pheno_rnai) {
		my $rnais_ar = $pheno_rnai{$phenotype};
		my @rnais = keys %$rnais_ar;
		print OUT "$phenotype\=\>@rnais\n";
	}
	print "OK\n";
}


sub get_pheno_variation_data { 
	
	my $self = shift;
	my $nay = shift;
	my %pheno_var;
	my $indir = $self->gene_datadir;
	my $outdir = $self->datadir;
	my $outfile = "pheno2vars.txt";
	
	if ($nay) {
		$outfile = "pheno2vars_not.txt";
	}
	
	open IN, "<$indir/variation_data.txt" or $self->log->logdie("Can't open infile");
	open OUT, ">$outdir/$outfile" or $self->log->logdie("Can't open outfile"); 

	while (<IN>) {	
		my ($gene,$var,$pheno,$not,$seqd) = split /\|/,$_;
		if ($nay) {
			if($not =~ m/not/i) {
				$pheno_var{$pheno}{$var} = 1;	
			}
			else {
				next;
			}
		}
		else {
			if ($not =~ m/not/i) {
				next;
			}
			else {
			$pheno_var{$pheno}{$var} = 1;
			}
		}
	}
	
	foreach my $phenotype (keys %pheno_var) {
		my $vars_ar = $pheno_var{$phenotype};
		my @vars = keys %$vars_ar;
		#my $rnais = join "|",@rnais;
		print OUT "$phenotype\=\>@vars\n";
	
	}
	print "OK\n";
}

sub get_pheno_xgene_data{

	my $self = shift;
	my 	%pheno_xgene;
	my $indir = $self->gene_datadir;
	my $outdir = $self->datadir;
	my $outfile = "pheno2xgenes.txt";
	
	open IN, "<$indir/gene_xgene_pheno.txt" or $self->log->logdie("Can't open in file");
	open OUT, ">$outdir/$outfile" or $self->log->logdie("Can't open outfile"); 
	
	while (<IN>) {
		my ($gene,$xgene,$pheno,$not) = split /\|/,$_;	
		$pheno_xgene{$pheno}{$xgene} = 1;
	}

	foreach my $phenotype (keys %pheno_xgene) {	
		my $xgenes_ar = $pheno_xgene{$phenotype};
		my @xgenes = keys %$xgenes_ar;
		print OUT "$phenotype\=\>@xgenes\n";
	}
	
	print "OK\n";
}

sub public_name { ## NEEDS UPDATE

	my $object = shift @_;
	my $common_name = 
		$object->Public_name
		|| $object->CGC_name
		|| $object->Molecular_name
		|| eval { $object->Corresponding_CDS->Corresponding_protein }
		|| $object;
	
	return $common_name;
}

sub call_list_paths {
	
	use DB_File;
	
	my ($self, $path_array,$id2parents_ref,$id2name_hr,$parent2ids_hr,$id2association_counts_hr) = @_;
	my @output;
	my $output_ar = \@output; 
	#our %id2parents = %{$id2parents_ref};
	#our %id2name = %{$id2name_hr};
	$self->list_paths($path_array, $id2parents_ref,$id2name_hr,$parent2ids_hr,$id2association_counts_hr); #$output_ar,

}

sub list_paths {

	## enter array
	
	my ($self, $destinations_ar, $id2parents_ref,$id2name_hr, $parent2ids_hr,$id2association_counts_hr) = @_; #$output_ar,
	my @destinations = @{$destinations_ar};
	my @output_array; # = @{$output_ar};
	my @path_builds;
	
	if (!(@destinations)){

		my @return_data;
		foreach my $output_path (@output_array){					
				my $name_path = '';
				my $full_info_name_path = '';
				my @destination = split '%',$output_path;
				while (@destination){
					my $step = shift @destination;
					my $old_step = $step;
					$step =~ s/^.*&//;
					$name_path = $name_path."|".$$id2name_hr{$step};
					$full_info_name_path = $full_info_name_path. "%".$old_step; ## ."&".$$id2name_hr{$step}
				}
		
				push @return_data,$full_info_name_path;
			}
		return @return_data;
	}
	else {
		## get path from entered array
		foreach my $destination (@destinations){
			# print "DESTINATION\:$destination\n";
			## get term at head of the path
			my ($parent) = split '%',$destination; #
	  		my $children;
			if ($parent) {
			    # my $discard;
			    $parent =~ s/^.*&//; 
			    # ($discard,$child) = split '\&',$child;
			    # print "$child\n";			    
			    $children = $$parent2ids_hr{$parent}; # $parents = $$id2parents_ref{$child}			
			}
			if($children){ ## $parents
				## get parents
				# print "PARENTS\:$parents\n";
				my  @children = split '\|', $children; ## @parents = split $parents;
				foreach my $child (@children) { ## $parent @parents
					## append parent to the rest of the path
					# print "append $parent to $child\n";
					my $updated_path = $child.'%'.$destination; ## $parent
					push @path_builds, $updated_path;
					## load path into array
				}
				
			}
			else {
				# print "FOR OUTPUT\:$destination\n";
				push @output_array, $destination;
			}
		} ### end foreach my $destination (@destinations)
		
		### print paths
		## enter array into program recursively
		list_paths(\@path_builds,\@output_array);
	}

}




1;
