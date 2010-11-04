package Update::CompileOntologyResources;

use base 'Update';
use DB_File;
use strict;

my %ontology2name = (go => 'gene',
		     po => 'phenotype',
		     ao => 'anatomy');

# The symbolic name of this step
sub step { return 'create ontology resources'; }

sub run {
    my $self = shift;
    
    my $release = $self->release;
    
    # The ontology directory should already exist.
    my $support_db_dir = $self->support_dbs;
    my $datadir = $support_db_dir . "/$release/ontology";
    
    # Additional paths and filenames
    
    $self->search_data_preprocessed_file("$datadir/search_data_preprocessed.txt");
    $self->go_obo_file("$datadir/gene_ontology.$release.obo");
    $self->go_assoc_file("$datadir/gene_association.$release.wb.ce");
    $self->ao_obo_file("$datadir/anatomy_ontology.$release.obo");
    $self->ao_assoc_file("$datadir/anatomy_association.$release.wb");
    $self->po_obo_file("$datadir/phenotype_ontology.$release.obo");
    $self->po_assoc_file("$datadir/phenotype_association.$release.wb");  
    
    $self->id2parents_file("$datadir/id2parents.txt");
    $self->parent2ids_file("$datadir/parent2ids.txt");
    $self->id2name_file("$datadir/id2name.txt");
    $self->name2id_file("$datadir/name2id.txt");
    $self->id2association_counts_file("$datadir/id2association_counts.txt");
    
    foreach my $ontology (keys %ontology2name) {	
	# compile search_data.txt  
	$self->compile_search_data($ontology);
	
	# compile id2parents relationships
	$self->compile_ontology_relationships($ontology,1);
	
	# compile parent2ids relationships
	$self->compile_ontology_relationships($ontology,2);
    }
    
    # compile id2name
    $self->parse_search_data(0,1,$self->id2name_file);
    $self->parse_search_data(1,0,$self->name2id_file);
    $self->parse_search_data(0,5,$self->id2association_counts_file);
    
    ## further compiles
    
    my @cmds;
	my $util_dir = "util";
	my $check_file = "$util_dir/ontology_check_file.txt";

	@cmds = (
		"clean_up_search_data.pl $release",
		"get_cummulative_association_counts.pl",
		"get_geneid2go_ids.pl",
		"get_pheno_gene_data_not.pl",
		"get_pheno_gene_data.pl",
		"get_pheno_rnai_data.pl",
		"get_pheno_variation_data.pl",
	    "get_pheno_rnai_data.pl 1",
		"get_pheno_variation_data.pl 1",
		"get_pheno_xgene_data.pl"
		);
		

	foreach my $cmd (@cmds) {
	
		Update::system_call($cmd, $check_file);
		print "$cmd done\n";
	}
 
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}


####################################################################################################
#
#  takes obo and association files and creates a table of annotations for terms in a given ontology
#  syntax make_sample_file <obo_file_name> <namespace> <association_file_name>
#
####################################################################################################

sub compile_search_data {
    my ($self,$type,) = @_;
    $self->logit->debug("compiling search_data.txt for $type");
    
    my $obo_tag   = $type . '_obo_file';
    my $assoc_tag = $type . '_assoc_file';
    my $obo_file_name         = $self->$obo_tag;
    my $association_file_name = $self->$assoc_tag;
    
    open HTML, "< $obo_file_name" or $self->logit->logdie("Cannot open the protein file: $obo_file_name; $!");
    my $target = $self->search_data_preprocessed_file;
    open OUT,">>$target" or $self->logit->logdie("Cannot open the output file $target");
    
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
# syntax: ontology_relations.pl <obo_file_name> and creates a two DB_File files using term ids as keys and  contains two listings, one of their parents, the other of the children.
# NB: abstract to work with specificid ontologies
###############################################################################################

sub compile_ontology_relationships {
    my ($self,$type,$format) = @_;
    $self->logit->debug("compiling ontology relationships for $type");
    
    my $obo_tag   = $type . '_obo_file';
    my $assoc_tag = $type . '_assoc_file';
    my $obo_file_name         = $self->$obo_tag;
    my $association_file_name = $self->$assoc_tag;
    
    my $output = ($format == 1) ? $self->id2parents_file : $self->parent2ids_file;
    
    open HTML, "< $obo_file_name" or $self->logit->logdie("Cannot open the protein file: $obo_file_name");
    open OUT,">>$output" or $self->logit->logdie("Cannot open the output file: $output $!");
    
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
    my ($self,$index_1,$index_2,$output) = @_;
    $self->logit->debug("parsing search data to $output");

    my $datafile = $self->search_data_preprocessed_file;
    open OUT, ">$output" or $self->logit->logdie("Cannot open the output file: $output $!");
    open FILE, "< /$datafile" or $self->logit->logdie("Cannot open $datafile");
    
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

1;
