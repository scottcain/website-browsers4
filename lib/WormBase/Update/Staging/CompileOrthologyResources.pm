package WormBase::Update::Staging::CompileOrthologyResources;

#######################################
#
# DEPRECATED. This module used to create a bunch of flat files
# for driving select elements of the website.
# These are no longer required.
#
#######################################

use lib "/usr/local/wormbase/website/tharris/extlib";
use Ace;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'compile orthology resources',
);

has 'datadir' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_datadir {
    my $self    = shift;
    my $release = $self->release;
    my $datadir =
      join( "/", $self->support_databases_dir, $release, 'orthology' );
    $self->_make_dir($datadir);
    return $datadir;
}

has 'ontology_datadir' => (
    is         => 'ro',
    lazy_build => 1
);


has 'precompile_datadir' => (
    is         => 'ro',
    lazy => 1,
	default => sub {
		my $self = shift;
		return "/usr/local/wormbase/website-admin/update/staging/orthology_data";
	}
);

sub _build_ontology_datadir {
    my $self    = shift;
    my $release = $self->release;
    my $ontology_datadir =
      join( "/", $self->support_databases_dir, $release, 'ontology' );
    return $ontology_datadir;
}

has 'dbh' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_dbh {
    my $self    = shift;
    my $release = $self->release;
    my $acedb   = $self->acedb_root;
    my $dbh     = Ace->connect( -path => "$acedb/wormbase_$release" )
      or $self->log->logdie("couldn't open ace:$!");
    return $dbh;
}

# The whole insane file list. Set up as accessors.
has 'gene_list_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_gene_list_file {
    my $self    = shift;
    return $self->datadir . "/gene_list.txt";
}


# The whole insane file list. Set up as accessors.
has 'omim2disease_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim2disease_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim2disease.txt";
}

has 'omim_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim.txt";
}


has 'omim_reconfigured_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_reconfigured_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_reconfigured.txt";
}


has 'disease_ace_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_disease_ace_file {
    my $self    = shift;
    return $self->datadir . "/Disease.ace";
}

# This is the SAME file as omim2disease.txt above.
has 'omim_id2disease_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2disease_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim2disease.txt";
}


has 'omim_id2disease_desc_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2disease_desc_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2disease_desc.txt";
}


has 'omim_id2disease_name_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2disease_name_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2disease_name.txt";
}


has 'omim_id2disease_notes_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2disease_notes_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2disease_notes.txt";
}


has 'omim_id2disease_synonyms_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2disease_synonyms_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2disease_synonyms.txt";
}

has 'omim_id2go_ids_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_omim_id2go_ids_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2go_ids.txt";
}


has 'go_id2omim_ids_txt_file' => (
    is         => 'ro',
    lazy_build => 1
);

sub _build_go_id2omim_ids_txt_file {
    my $self    = shift;
    return $self->datadir . "/go_id2omim_ids.txt";
}

has 'id2name_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_id2name_txt_file {
    my $self    = shift;
    return $self->datadir . "/id2name.txt";
}

has 'disease_search_data_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_disease_search_data_txt_file {
    my $self    = shift;
    return $self->datadir . "/disease_search_data.txt";
}


has 'omim_id2gene_name_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_omim_id2gene_name_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2gene_name.txt";
}




has 'ortholog_other_data_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_ortholog_other_data_txt_file {
    my $self    = shift;
    return $self->datadir . "/ortholog_other_data.txt";
}

has 'ortholog_other_data_hs_only_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_ortholog_other_data_hs_only_txt_file {
    my $self    = shift;
    return $self->datadir . "/ortholog_other_data_hs_only.txt";
}


has 'gene_id2phenotype_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_gene_id2phenotype_txt_file {
    my $self    = shift;
    return $self->datadir . "/gene_id2phenotype.txt";
}

has 'full_disease_data_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_full_disease_data_txt_file {
    my $self    = shift;
    return $self->datadir . "/full_disease_data.txt";
}

has 'disease_page_data_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_disease_page_data_txt_file {
    my $self    = shift;
    return $self->datadir . "/disease_page_data.txt";
}

has 'all_proteins_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_all_proteins_txt_file {
    my $self    = shift;
    return $self->datadir . "/all_proteins.txt";
}

has 'hs_ensembl_id2omim_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_hs_ensembl_id2omim_txt_file {
    my $self    = shift;
    return $self->datadir . "/hs_ensembl_id2omim.txt";
}

has 'hs_proteins_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_hs_proteins_txt_file {
    my $self    = shift;
    return $self->datadir . "/hs_proteins.txt";
}

has 'gene_association_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_gene_association_file {
    my $self    = shift;
    my $release = $self->release;
    return $self->ontology_datadir . "/gene_association." . $release . ".wb.ce";
}

has 'morbidmap_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_morbidmap_txt_file {
    my $self    = shift;
    return $self->datadir . "/morbidmap";
}

has 'omim_id2all_ortholog_data_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_omim_id2all_ortholog_data_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2all_ortholog_data.txt";
}

has 'omim_id2phenotypes_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_omim_id2phenotypes_txt_file {
    my $self    = shift;
    return $self->datadir . "/omim_id2phenotypes.txt";
}



has 'gene_id2omim_ids_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_gene_id2omim_ids_txt_file {
    my $self    = shift;
    return $self->datadir . "/gene_id2omim_ids.txt";
}









sub run {
    my $self         = shift;
    $self->compile_gene_list();	
    $self->get_all_ortholog_other_data();   
    $self->get_precompile_data();
    $self->reconfigure_omim_file();

    $self->get_all_associated_phenotypes();    # creates gene_id2phenotype.txt
    $self->pull_omim_desc();                   # creates omim_id2disease_desc.txt

    $self->get_all_associated_go_terms('F');   # creates gene_id2go_mf.txt
    $self->get_all_associated_go_terms('P');   # creates gene_id2go_bp.txt
 
    $self->pull_omim_txt_notes();              # creates omim_id2disease_notes.txt
    $self->process_omim_2_disease_data();      # creates omim2disease.txt
    $self->print_hs_ortholog_other_data();     # creates ortholog_other_data_hs_only.txt
    $self->update_hs_protein_list();           # creates all_proteins.txt and hs_proteins.txt
    $self->process_ensembl_2_omim_data();      # creates hs_ensembl_id2omim.txt
    $self->assemble_disease_data();             # creates full_disease_data.txt
    $self->print_disease_page_data();           # creates disease_page_data.txt
 
    $self->log->info("processing omim 2 all ortholog data");
    $self->process_pipe_delineated_file($self->disease_page_data_txt_file,
					 1,
					 '0-1-2-3-4-5-6-7-8-9-10-11-12', 0,
					 $self->omim_id2all_ortholog_data_txt_file);
    
    $self->log->info("processing omim 2 all ortholog data done");

    $self->pull_disease_synonyms();
 
    $self->log->info("processing omim 2 phenotype");
    $self->process_pipe_delineated_file($self->disease_page_data_txt_file, 1, '8', 1,
					$self->omim_id2phenotypes_txt_file);
     $self->log->info("processing omim 2 phenotype done");
 
     $self->log->info("processing omim 2 go id file");
     $self->process_pipe_delineated_file($self->disease_page_data_txt_file,
					 1, '9-10',
					 1, 
					 $self->omim_id2go_ids_txt_file);
     $self->log->info("processing omim 2 go id file done");
 	
    $self->log->info("processing omim to disease name file");
    $self->process_pipe_delineated_file($self->disease_page_data_txt_file,
					1,'0',0,$self->omim_id2disease_name_txt_file );
    $self->log->info("processing omim to disease name file done");
 	
    $self->log->info("processing gene_id to omim_ids file");
    $self->process_pipe_delineated_file($self->disease_page_data_txt_file,
					2,'1',1,$self->gene_id2omim_ids_txt_file);
    $self->log->info("processing gene_id to omim_ids file done");
    
    
    $self->compile_omim_go_data();
    $self->assemble_search_data();
    $self->process_omim_id2_gene_name();
    
    $self->create_disease_file();
}

###################
#
# METHODS
#
###################


# This is an old script from Norie. 
# It creates a file called "databases/WSXXX/ortholgy/gene_list.txt
# that simply lists all genes that have an ortholog_other
# I have no idea how or where this file is used.
sub compile_gene_list {
    my $self = shift;
    $self->log->info("creating gene_list.txt");	
    
    my $outfile = $self->gene_list_file;

    open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open gene_list output file");
    my $class = 'Gene';
    my $genes = $self->dbh->fetch_many(-class => $class);
    
    while (my $gene = $genes->next){
#	my @oo = $gene->Ortholog_other;
	
	if ($gene->Ortholog_other) {
	    print OUTFILE "$gene\n";
	} else {
	    next;
	}
    }
    close OUTFILE;
    
    $self->log->debug("creating gene_list.txt file done");
}



sub create_disease_file {
    my $self = shift;

    my $outfile = $self->disease_ace_file;
    my $omim_id2disease_txt_file     = $self->omim_id2disease_txt_file;
    my $omim_id2disease_desc_txt_file   = $self->omim_id2disease_desc_txt_file;
    my $omim_id2disease_notes_txt_file  = $self->omim_id2disease_notes_txt_file;
    my $omim_id2disease_synonyms_txt_file = $self->omim_id2disease_synonyms_txt_file;    
    my $omim_id2go_ids_txt_file           = $self->omim_id2go_ids_txt_file;
    my $id2name_txt_file                  = $self->id2name_txt_file;
    my $omim_id2gene_name_file            = $self->omim_id2gene_name_txt_file;
		
	open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open disease output file");
	my %omim_id2disease       = $self->build_hash($omim_id2disease_txt_file);
	my %omim_id2disease_desc = $self->build_hash($omim_id2disease_desc_txt_file);
	my %omim_id2disease_notes = $self->build_hash($omim_id2disease_notes_txt_file);
	my %omim_id2disease_synonyms = $self->build_hash($omim_id2disease_synonyms_txt_file);
	my %omim_id2go_ids = $self->build_hash($omim_id2go_ids_txt_file);
	my %id2name = $self->build_hash($id2name_txt_file);
	my %omim_id2genes = $self->build_hash($omim_id2gene_name_file);
	
	foreach my $omim_id (keys %omim_id2disease) {
		my $description = $omim_id2disease_desc{$omim_id};
		$description =~ s/\<br>//g;
		my $notes = $omim_id2disease_notes{$omim_id};
		$notes=~ s/\<br>//g;
		my $synonym_line = $omim_id2disease_synonyms{$omim_id};
		my @synonyms = split ";",$synonym_line;
		my $go_ids = $omim_id2go_ids{$omim_id};
		$go_ids=~ s/\%//g;
		$go_ids=~ s/\|/&/g;
		my @go_ids = split "&",$go_ids;
		my $genes = $omim_id2genes{$omim_id};
		my @genes = split / /,$genes;
		
		print OUTFILE 
"Disease : $omim_id
name\t\"$omim_id2disease{$omim_id}\"
description\t \"$description\"
notes\t\"$notes\"\n";
		foreach my $synonym (@synonyms) {
			print OUTFILE 
"synonym \t\"$synonym\"\n";
		}
		foreach my $go_id (@go_ids) {
			print OUTFILE 
"GO_Term\t$go_id\tTerm\t\"$id2name{$go_id}\"\n";			
		}
		foreach my $gene (@genes) {
			print OUTFILE 
"gene\t\"$gene\"\n";			
		}
		print OUTFILE "\n";
	}
}

############################

sub get_all_ortholog_other_data {
    my $self = shift;
    
    $self->log->info("creating ortholog_other_data.txt");
    my $gene_list = $self->gene_list_file;
    my $ortholog_other_data_txt_file = $self->ortholog_other_data_txt_file;
    my $DB = $self->dbh;
    
    open GENELIST, "< $gene_list" or die "Cannot open $gene_list for getting orthologs\n";
    
    my $gene_id;
    open OUT, ">> $ortholog_other_data_txt_file" or die "Cannot open $ortholog_other_data_txt_file\n"; 
    
    foreach my $gene_id (<GENELIST>) {
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
#	system("echo $gene_id > $datadir/$last_processed_gene_txt");		
    }	
    $self->log->debug("get_all_ortholog_other_data done");
}

sub get_precompile_data {
    my $self = shift;

    $self->log->info("getting precompiled data");

    my $release = $self->release;
    my $onto_gene_association_file = "gene_association." . $release . ".wb.ce";


    my $datadir            = $self->datadir;
    my $ontology_datadir   = $self->ontology_datadir;
    my $precompile_datadir = $self->precompile_datadir;
        
    # system_call -- set up a template
    my $pull_external_data_command = "cp $precompile_datadir/* $datadir";
    $self->system_call( $pull_external_data_command, $pull_external_data_command );
    
    # Copy files from databases/WSVER/ontology    
    # id2name.txt
    my $copy_id2name_cmd = "cp $ontology_datadir\/id2name.txt $datadir";
    $self->system_call( $copy_id2name_cmd, $copy_id2name_cmd );
    
    # name2id.txt
    my $copy_name2id_cmd = "cp $ontology_datadir\/name2id.txt $datadir";
    $self->system_call( $copy_name2id_cmd, $copy_name2id_cmd );
    
    # gene_association file
    my $copy_gene_association_cmd =
	"cp $ontology_datadir\/$onto_gene_association_file $datadir";
    $self->system_call( $copy_gene_association_cmd, $copy_gene_association_cmd );
    
    # unzip OMIM file
    my $unzip_cmd = "gunzip $datadir/omim.txt.Z";
    $self->system_call( $unzip_cmd, $unzip_cmd );

    $self->log->debug("get_precompile_data done");
}

sub reconfigure_omim_file {
    my $self      = shift;
    $self->log->info("reconfiguring OMIM file");

    my $omim_txt_file = $self->omim_txt_file;
    my $omim_reconfigured_txt_file   = $self->omim_reconfigured_txt_file;
    open OMIM, "< $omim_txt_file" or $self->log->logdie("Cannot open $omim_txt_file");
    open OUT,  "> $omim_reconfigured_txt_file"  or $self->log->logdie("Cannot open $omim_reconfigured_txt_file");

    my $header;
    my @line_elements;

    foreach my $line (<OMIM>) {
        chomp $line;
        if ( $line eq "\*RECORD\*" ) {

            # chomp $line;
            print OUT "$header\=>";
            print OUT ( join " ", @line_elements );
            print OUT "\n";
            print OUT "$line\n";
            @line_elements = ();
        }
        elsif ( $line =~ m/^\*FIELD\*/ ) {

            # chomp $line;
            print OUT "$header\=>";
            print OUT ( join " ", @line_elements );
            print OUT "\n";
            $header        = $line;
            @line_elements = ();

        }
        elsif ( $line =~ m/^[A-Z\s]*$/ ) {
            if ( !( $line =~ m/^*./ ) ) {
                push @line_elements, "$line\<br>";
            }
            else {

                # chomp $line;
                print OUT "$header\=>";
                print OUT ( join " ", @line_elements );
                print OUT "\n";
                $header        = "*" . $line;
                @line_elements = ();
            }
        }
        else {
            push @line_elements, "$line";
        }
    }
    $self->log->info("reconfiguring OMIM file done");
}


# Phenotypes are no longer attached directly to Genes.  This won't work.
sub get_all_associated_phenotypes {
    my ($self) = @_;
    $self->log->info("getting associated phenes");
    
    my $gene_id2phenotype_txt_file  = $self->gene_id2phenotype_txt_file;
    
#    my $class             = 'Gene';
#    my $tag               = 'Phenotype';
#    my $aql_query         = "select all class $class where exists_tag ->$tag";
    my $DB = $self->dbh;
#    my @objects_full_list = $DB->aql($aql_query);
    open OUT, "> $gene_id2phenotype_txt_file" or $self->log->logdie("Cannot open $gene_id2phenotype_txt_file");

    my $i = $DB->fetch_many(-class=>'Gene');
    
#    foreach my $object (@objects_full_list) {
    while (my $gene = $i->next){
	my @variations = $gene->Allele;
	my %phenes;
	foreach (@variations) {
	    map { $phenes{$_}++ } $_->Phenotype;
	}
	next unless (keys %phenes > 0);
	foreach my $phenotype (keys %phenes) {
	    print OUT "$gene\=\>$phenotype\n";
	}
    }
    $self->log->info("getting associated phenes done");
}

sub pull_omim_desc{
    my $self = shift;

    $self->log->info("pulling omim descriptions");
    
    my $omim_txt_file = $self->omim_txt_file;
    my $omim_reconfigured_txt_file   = $self->omim_reconfigured_txt_file;
    my $omim_id2disease_desc_txt_file= $self->omim_id2disease_desc_txt_file;
    
    open OMIM,"< $omim_reconfigured_txt_file" or die "Cannot open $omim_reconfigured_txt_file\n";
    open OUT, "> $omim_id2disease_desc_txt_file" or die "Cannot open $omim_id2disease_desc_txt_file";
    my $id;
    my $tx;
    my $discard;
    my $dump;
    my $desc_n_tx;
    my $desc;
    my $dump_too;
    foreach my $line (<OMIM>){
	chomp $line;
	if($line eq "\*RECORD\*"){
	    print OUT "$id\=\>$desc\n";
	    undef $id;
	    undef $desc;
	}       
	elsif($line =~ m/^\*FIELD\*\ NO/){
	    ($discard,$id) = split /\=\>/,$line;
	}
	elsif($line =~ m/^\*DESCRIPTION/){
	    ($discard,$desc) = split /\=\>/,$line;
	    # print "$tx\n";
	    # ($dump,$desc_n_tx) = split "DESCRIPTION",$tx;
	    # print "2\:$desc_n_tx\n";
	    # ($desc, $dump_too) = split //,$desc_n_tx;
	}
	else {
	    next;
	}
    }
    $self->log->info("pulling omim descriptions done");
}

sub get_all_associated_go_terms {
    my $self = shift;
    my $aspect = shift; # aspect: F,C, or P for molecular fucntion, cellelular component, and biological process respectively
    my $gene_association_file = $self->gene_association_file;	
    
    $self->log->info("getting associated function go terms");
    my $prefix;
    if ($aspect eq 'F') {
	$prefix = 'mf';
    } elsif ($aspect eq 'P') {
	$prefix = 'bp';
    } else {
	$prefix = 'cc';
    }
    my $datadir = $self->datadir;
    my $outfile      = "$datadir/gene_id2go_$prefix.txt";
    
    open DATAFILE, "< $gene_association_file" or $self->log->logdie("Cannot open $gene_association_file");
    open OUT,      "> $outfile"  or $self->log->logdie("Cannot open $outfile");
    
    my %data_hash;
    
    foreach my $line (<DATAFILE>) {
        chomp $line;
	
        # print "$line\n";
        my @line_elements = split /\t/, $line;
	
        # print "LE: $line_elements[1]\|$line_elements[4]\|$line_elements[8]\n";
        $data_hash{ $line_elements[1] }{ $line_elements[8] }
	{ $line_elements[4] } = 1;
    }
    
    foreach my $go_id ( keys %data_hash ) {
        my $go_terms_hr = $data_hash{$go_id}{$aspect};
        if ($go_terms_hr) {
            my $term_list = join "&", ( keys %{$go_terms_hr} );
            print OUT "$go_id\=\>$term_list\n";
        }
        else {
            next;
        }
    }
    $self->log->info("getting associated function go terms done");
}


sub pull_omim_txt_notes {
    my $self        = shift;
    $self->log->info("getting omim text notes");


    my $input_file  = $self->omim_reconfigured_txt_file;    
    my $output_file = $self->omim_id2disease_notes_txt_file;

    open OMIM, "< $input_file"  or $self->log->logdie("Cannot open $input_file");
    open OUT,  "> $output_file" or $self->log->logdie("Cannot open $output_file");

    my $id;
    my $tx;
    my $discard;
    my $dump;
    my $desc_n_tx;
    my $desc;
    my $dump_too;
    foreach my $line (<OMIM>) {
        chomp $line;
        if ( $line eq "\*RECORD\*" ) {
            if ( !( $desc eq '<br>' ) ) {
                print OUT "$id\=\>$desc\n";
            }
            undef $id;
            undef $desc;
        }
        elsif ( $line =~ m/^\*FIELD\*\ NO/ ) {
            ( $discard, $id ) = split /\=\>/, $line;
            $id =~ s/<br>//;
        }
        elsif ( $line =~ m/^\*FIELD\*\ TX/ ) {
            ( $discard, $desc ) = split /\=\>/, $line;

            # print "$tx\n";
            # ($dump,$desc_n_tx) = split "DESCRIPTION",$tx;
            # print "2\:$desc_n_tx\n";
            # ($desc, $dump_too) = split //,$desc_n_tx;
        }
        else {
            next;
        }
    }
     $self->log->info("getting omim text notes done");
}

sub process_omim_2_disease_data {
    my $self     = shift;
    $self->log->info("processing omim 2 disease data");

    my $filename = $self->morbidmap_txt_file;
    my $outfile = $self->omim2disease_txt_file;

    open FILE, "< $filename" or $self->log->logdie("Cannot open $filename");
    open OUT,  "> $outfile"  or $self->log->logdie("Cannot open $outfile");

    foreach my $line (<FILE>) {
        chomp $line;
        my @line_elements = split '\|', $line;
        $line_elements[0] =~ s/\(.\)//g;

        if ( $line_elements[0] =~ m/[0-9]{6}/ ) {
            my @disease_data = split ",", $line_elements[0];
            my $omim_id = pop @disease_data;
            $omim_id =~ s/ //g;
            my @disease_names;
            foreach my $disease_datum (@disease_data) {
                $disease_datum =~ s/[{*,}*]//g;
                $disease_datum =~ s/\[*//g;
                $disease_datum =~ s/\]*//g;
                push @disease_names, $disease_datum;
            }
            my $disease_name = join ",", @disease_names;
            print OUT "$omim_id\=\>$disease_name\n";
        }

        else {

            $line_elements[0] =~ s/[{*,}*]//g;
            $line_elements[0] =~ s/\[*//g;
            $line_elements[0] =~ s/\]*//g;
            print OUT "$line_elements[2]\=\>$line_elements[0]\n";
        }
    }
    $self->log->info("processing omim 2 disease data done");
}


sub print_hs_ortholog_other_data {
    my $self     = shift;
    $self->log->info("printing hs orthology other data");
 
    my $infile  = $self->ortholog_other_data_txt_file;
    my $outfile = $self->ortholog_other_data_hs_only_txt_file;

    open OUT, "> $outfile" or $self->log->logdie("Cannot open $outfile");

    my $data = `grep sapiens $infile`;
    print OUT $data;
    $self->log->info("printing hs orthology other data done");
}

sub update_hs_protein_list {
    my $self             = shift;
     $self->log->info("updating hs protein list");
    my $datadir = $self->datadir;

    my $all_protein_list = $self->all_proteins_txt_file;
    my $hs_protein_list  = $self->hs_proteins_txt_file;

    my $DB = $self->dbh;

    open ALL_PROTEIN_LIST, "$all_protein_list"
      or $self->log->logdie("Cannot open all protein list");

    ## build protein hash
    my %all_proteins;

    foreach my $protein_id (<ALL_PROTEIN_LIST>) {
        chomp $protein_id;
        $all_proteins{$protein_id} = 1;
    }

    close ALL_PROTEIN_LIST;

    open ALL_PROTEIN_LIST, ">>$all_protein_list"
      or $self->log->logdie("Cannot open all protein list");
    open HS_PROTEIN_LIST, ">>$hs_protein_list"
      or $self->log->logdie("Cannot open hs protein list");

    ### get and check protein data

    my @acedb_proteins = $DB->fetch( -class => 'Protein' );

    foreach my $ace_protein (@acedb_proteins) {
        if ( $all_proteins{$ace_protein} ) {
            next;
        }
        else {
            my $sp = $ace_protein->Species;
            if ( $sp =~ m/sapien/ ) {
                print ALL_PROTEIN_LIST "$ace_protein\n";
                print HS_PROTEIN_LIST "$ace_protein\n";
            }
            else {
                print ALL_PROTEIN_LIST "$ace_protein\n";
            }
        }
    }
    $self->log->info("updating hs protein list done");
}

sub process_ensembl_2_omim_data {
    my $self = shift;
    my $datadir = $self->datadir;
     $self->log->info("processing ensembl 2 omim data");

    my $DB = $self->dbh;

    my $infile  = $self->hs_proteins_txt_file;
    my $outfile = $self->hs_ensembl_id2omim_txt_file;
    
    open INFILE,  "$infile"    or $self->log->logdie("Cannot open $infile");
    open OUTFILE, "> $outfile" or $self->log->logdie("Cannot open $outfile");

    foreach my $object_name (<INFILE>) {
        chomp $object_name;
        my $db_info;
        my @data;

        my $object = $DB->fetch( -class => 'Protein', -Name => $object_name );
        eval { $db_info = $object->DB_info; };    ### end eval
        eval { @data    = $db_info->col; };

        foreach my $db_data (@data) {
            if ( $db_data =~ m/OMIM/ ) {
                my @db_data;
                eval { @db_data = $db_data->col; };
                foreach my $omim_data (@db_data) {
                    if ( $omim_data =~ m/disease/ ) {
                        my $disease_id;
                        eval { $disease_id = $omim_data->right; };
                        my ( $ensembl, $ensembl_id ) = split /:/, $object_name;
                        print OUTFILE "$ensembl_id\=\>";    #
                        print OUTFILE "$disease_id\n";      #

                    }

                }

            } ## end if ($db_data =~ m/OMIM/)
        }    # end foreach my $db_data (@data)
    }    # end foreach my $db_data (@data)
     $self->log->info("processing ensembl 2 omim data done");
}

sub assemble_disease_data {
    my $self = shift;   
    $self->log->info("assembling disease data");
   
    my $datadir = $self->datadir;
    my $omim_id2disease_txt_file       = $self->omim_id2disease_txt_file;
    my $omim_id2disease_desc_txt_file  = $self->omim_id2disease_desc_txt_file;
    my $omim_id2disease_notes_txt_file = $self->omim_id2disease_notes_txt_file;
    my $gene_id2phenotype_txt_file     = $self->gene_id2phenotype_txt_file;
    
    my $filename = $self->ortholog_other_data_hs_only_txt_file;

    my $outfile  = $self->full_disease_data_txt_file;

    # my $hs_ensembl_id2omim_txt_file =
    my $hs_ensembl_id2omim_txt_file = $self->hs_ensembl_id2omim_txt_file;

    my $gene_id2go_bp_txt_file = "$datadir/gene_id2go_bp.txt";
    my $gene_id2go_mf_txt_file = "$datadir/gene_id2go_mf.txt";

    my %hs_gene_id2omim_id    = $self->build_hash($hs_ensembl_id2omim_txt_file);
    my %omim_id2disease       = $self->build_hash($omim_id2disease_txt_file);
    my %omim_id2disease_desc  = $self->build_hash($omim_id2disease_desc_txt_file);
    my %omim_id2disease_notes = $self->build_hash($omim_id2disease_notes_txt_file);
    my %gene_id2go_bp         = $self->build_hash($gene_id2go_bp_txt_file);
    my %gene_id2go_mf         = $self->build_hash($gene_id2go_mf_txt_file);
    my %gene_id2phenotype     = $self->build_hash($gene_id2phenotype_txt_file);

    open FILE, "< $filename" or $self->log->logdie("Cannot open $filename");
    open OUT,  "> $outfile"  or $self->log->logdie("Cannot open $outfile");

    foreach my $line (<FILE>) {
        my $disease;
        my $omim_id;

        chomp $line;
        my ( $wb_id, $db, $ortholog_id, $sp, $analysis, $method ) = split /\|/, $line;
        my $phenotype;
        my $functions;
        my $biological_processes;
        my %data;

	
	
        if ( $hs_gene_id2omim_id{$ortholog_id} ) {
            $omim_id = $hs_gene_id2omim_id{$ortholog_id};
        } else {
            $omim_id = "NO_OMIM";
        }
	print "ORTHOLOG ID: $ortholog_id; WB ID: $wb_id\n"; 
	print "OMIM ID: $omim_id\n";


        if ( $omim_id2disease{$omim_id} ) {
            $disease = $omim_id2disease{$omim_id};
        }
        else {
            $disease = "NO_DISEASE";
        }

        print OUT "$disease\|$omim_id\|$line\|$gene_id2phenotype{$wb_id}\|$gene_id2go_bp{$wb_id}\|$gene_id2go_mf{$wb_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\n";
    }

    $self->log->info("assembling disease data done");
}

sub print_disease_page_data {
    my $self = shift;
     $self->log->info("printing disease page data");

    my $in_file = $self->full_disease_data_txt_file;
    my $out_file = $self->disease_page_data_txt_file;

    system("grep -v NO_DISEASE $in_file > $out_file");
#    $self->system_call( $grep_cmd, $grep_cmd );
    $self->log->info("printing disease page data done");
}

sub process_pipe_delineated_file {
    ### arguments
    my ( $self, $datafile, $key_index, $value_index_list, $multi, $outfile ) =
      @_;
    my @value_indices = split "-", $value_index_list;
    my %recompiled_data;

    my $datadir = $self->datadir;
    open DATAFILE, "< $datafile" or $self->log->logdie("Cannot open $datafile");
    open OUT,      "> $outfile"  or $self->log->logdie("Cannot open $outfile");

    foreach my $line (<DATAFILE>) {
        chomp $line;
        my @line_elements = split /\|/, $line;
        my $value = $recompiled_data{ $line_elements[$key_index] };
        my @value_line;
        foreach my $value_index (@value_indices) {
            push @value_line, $line_elements[$value_index];
        }
        my $value_line = join "|", @value_line;

        if ( $value && $multi ) {
            if ( $value_line =~ m/$value/ ) {
                next;
            }
            else {
                $recompiled_data{ $line_elements[$key_index] } = join '%',
                  ( $value, $value_line );
            }
        }
        else {
            $recompiled_data{ $line_elements[$key_index] } = $value_line;
        }
    }
    foreach my $key ( keys %recompiled_data ) {
        print OUT "$key\=\>$recompiled_data{$key}\n";    #
    }
}

sub pull_disease_synonyms {
    my $self = shift;
    $self->log->info("getting disease synonyms");
    my $omim_txt_file = $self->omim_txt_file;

    #   my $omim_id2disease_synonyms_txt_file =
    my $outfile = $self->omim_id2disease_synonyms_txt_file;

    open OMIM, "<$omim_txt_file" or $self->log->logdie("Cannot open $omim_txt_file");
    open OUT,  "> $outfile"  or $self->log->logdie("Cannot open outfile");

    my $header;
    my @line_elements;
    my @lines;

    foreach my $line (<OMIM>) {
        chomp $line;
        if ( !( $line =~ m/^*./ ) ) {
            next;
        }
        elsif ( $line eq "\*RECORD\*" ) {
            my $hold_line = $header . "=>" . ( join " ", @line_elements );
            push @lines, $hold_line;
            push @lines, "$line";
            @line_elements = ();
        }
        elsif ( $line =~ m/^\*FIELD\*/ ) {
            my $hold_line = $header . "=>" . ( join " ", @line_elements );
            push @lines, $hold_line;

            # push @lines, "$line\n";
            $header        = $line;
            @line_elements = ();
        }
        else {
            push @line_elements, $line;
        }
    }

    foreach my $output_line (@lines) {
        if ( $output_line =~ m/MOVED/ ) {
            next;
        }
        elsif ( $output_line =~ m/^\*FIELD\*\ TI/ ) {
            if ( $output_line =~ m/MOVED/ ) {
                next;
            }
            else {
                $output_line =~ s/^\*FIELD\*\ TI\=\>//;
                $output_line =~ s/[#^*%+]//;
                $output_line =~ s/\;\;/\ \&\ /g;
                $output_line =~ s/\ /=>/;
                print OUT "$output_line\n";
            }
        }
        else {
            next;
        }

    }
    $self->log->info("getting disease synonyms done");    
}

sub compile_omim_go_data {
    my $self = shift;
    my $datadir = $self->datadir;

    my $omim_id2go_ids_txt_file = $self->omim_id2go_ids_txt_file;
    my $outfile = $self->go_id2omim_ids_txt_file;
 
    $self->log->info("compiling omim go data");

   my %omim_id2go_ids = $self->build_hash($omim_id2go_ids_txt_file);
    my %go_id2omim_id;

    open OUT, "> $outfile" or $self->log->logdie("Cannot open $outfile");

    foreach my $omim_id ( keys %omim_id2go_ids ) {
        my $go_ids = $omim_id2go_ids{$omim_id};
        $go_ids =~ s/\|/&/g;
        $go_ids =~ s/&&*/&/g;

        if ($go_ids) {
            my @go_ids = split "&", $go_ids;
            foreach my $go_id (@go_ids) {
                $go_id2omim_id{$go_id}{$omim_id} = 1;
            }
        }
    }

    # my %go_id2omim_ids;

    foreach my $go_id ( keys %go_id2omim_id ) {
        if ($go_id) {
            print OUT "$go_id\=\>";
            my $omim_id_hr = $go_id2omim_id{$go_id};
            my $omim_id_line = join "|", keys %{$omim_id_hr};
            print OUT "$omim_id_line\n";
        }
        else {
            next;
        }
    }
    $self->log->info("compiling omim go data done");
}

sub assemble_search_data {
    my $self = shift;

    my $datadir = $self->datadir;
    $self->log->info("assembling search data");

    my $outfile = $self->disease_search_data_txt_file;

    my $omim_id2all_ortholog_data_txt_file = $self->omim_id2all_ortholog_data_txt_file;

    my $omim_id2disease_name_txt_file  = $self->omim_id2disease_name_txt_file;
    my $omim_id2disease_desc_txt_file  = $self->omim_id2disease_desc_txt_file;
    my $omim_id2disease_notes_txt_file = $self->omim_id2disease_notes_txt_file;
    my $omim_id2disease_synonyms_txt_file = $self->omim_id2disease_synonyms_txt_file;
    my $omim_id2phenotypes_txt_file    = $self->omim_id2phenotypes_txt_file;
	
    my %omim2all_ortholog_data =
      $self->build_hash($omim_id2all_ortholog_data_txt_file);
    my %omim2disease_name     = $self->build_hash($omim_id2disease_name_txt_file);
    my %omim_id2disease_desc  = $self->build_hash($omim_id2disease_desc_txt_file);
    my %omim_id2disease_notes = $self->build_hash($omim_id2disease_notes_txt_file);
    my %omim_id2disease_synonyms =
      $self->build_hash($omim_id2disease_synonyms_txt_file);
    my %omim_id2phenotypes = $self->build_hash($omim_id2phenotypes_txt_file);

    open OUT, "> $outfile" or $self->log->logdie("Cannot open $outfile");

    foreach my $omim_id ( keys %omim2all_ortholog_data ) {
        print OUT
"$omim_id\|$omim2disease_name{$omim_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\|$omim_id2disease_synonyms{$omim_id}\|$omim_id2phenotypes{$omim_id}\n";
    }
     $self->log->info("assembling search data done");
}

sub process_omim_id2_gene_name {
    my $self = shift;

    $self->log->info("processing omim 2 gene name");

    my $gene_id2omim_ids_txt_file  = $self->gene_id2omim_ids_txt_file;
    my $omim_id2_gene_name_file    = $self->omim_id2gene_name_txt_file;

    my %gene_id2omim_ids = $self->build_hash($gene_id2omim_ids_txt_file);
    my %omim_id2gene_ids;
    my $DB = $self->dbh;

    open OUT, ">$omim_id2_gene_name_file";

    foreach my $gene_id ( keys %gene_id2omim_ids ) {
        my $gene_obj;
        my $gene_cgc;
        my $gene_seq;
        my $omim_id_line;
        my @omim_ids;

        $gene_obj = $DB->fetch( -class => 'Gene', -name => $gene_id );

        eval { $gene_cgc = $gene_obj->CGC_name; };
        eval { $gene_seq = $gene_obj->Sequence_name; };

        $omim_id_line = $gene_id2omim_ids{$gene_id};
        @omim_ids = split "%", $omim_id_line;

        foreach my $omim_id (@omim_ids) {
            $omim_id2gene_ids{$omim_id}{$gene_cgc} = 1;
            $omim_id2gene_ids{$omim_id}{$gene_seq} = 1;
        }
    }

    foreach my $omim_id ( keys %omim_id2gene_ids ) {
        my $gene_ids = $omim_id2gene_ids{$omim_id};
        my @gene_ids = keys %$gene_ids;
        print OUT "$omim_id\=\>@gene_ids\n";
    }
    $self->log->info("processing omim 2 gene done");
}


1;






=pod

Once the classic site is retired, CompileOrthologyResources.pm becomes

package WormBase::Update::Staging::CompileOrthologyResources;


use lib "/usr/local/wormbase/website/tharris/extlib";
use Ace;
use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'compile orthology resources',
);

has 'dbh' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_dbh {
    my $self = shift;
    my $release = $self->release;
    my $acedb = $self->acedb_root;
    my $dbh = Ace->connect( -path => "$acedb/wormbase_$release" )
       or $self->log->logdie("couldn't open ace:$!");
    return $dbh;
}

has 'datadir' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_datadir {
    my $self = shift;
    my $release = $self->release;
    my $datadir =
      join( "/", $self->support_databases_dir, $release, 'orthology' );
    $self->_make_dir($datadir);
    return $datadir;
}

has 'gene2omim_file' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_gene2omim_file {
    my $self = shift;
    return $self->datadir . "/gene2omim.txt";
}

has 'morbidmap_txt_file' => (
    is => 'ro',
    lazy_build => 1
    );

sub _build_morbidmap_txt_file {
    my $self = shift;
    return $self->datadir . "/morbidmap";
}

has 'omim_txt_file' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_omim_txt_file {
    my $self = shift;
    return $self->datadir . "/omim.txt";
}

has 'disease_ace_file' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_disease_ace_file {
    my $self = shift;
#    return $self->datadir . "/Disease.ace";
    return "/usr/local/wormbase/tmp/acedmp/Disease.ace";
}


sub run {
    my $self = shift;
    #this step will takes a while: ~ 13 mins
    $self->log->info("building wormbase gene_id to omim_id corelation based on the ortholog human(Ensembl) protein");
    $self->compile_gene2omim();

    $self->log->info("reading genelist file to get the related wormbase gene information"); 
    my $hash= $self->read_gene_file();

    $self->log->info("reading omim morbid file to get the related human gene information"); 
    my $mm_hash = $self->read_omim_file();

    $self->log->info("generating Disease.ace file for xapian");
    $self->create_disease_file($hash,$mm_hash);  # create Disease.ace 
}

sub compile_gene2omim{
    my $self     = shift;
   
    my $outfile = $self->gene2omim_file;
    open OUTFILE, ">$outfile" or $self->log->logdie("Cannot open  $outfile file");
    
    my $db= $self->dbh;
    my $iterator = $db->fetch_many(Protein => 'ENSEMBL:ENSP*');
   
    while (my $obj = $iterator->next) {
	  my $wbgene = $obj->Ortholog_gene;
	  next unless($wbgene);
	  my @omim = grep {/OMIM/} map {$_} $obj->Database;
	  next unless(@omim);
	  $obj =~ s/ENSEMBL://g;
	  print OUTFILE "$obj","\t",$wbgene,"\t",join("\t",map{$_.":".$_->right} $omim[0]->col)," \n";
    }  
    close(OUTFILE);
}

sub read_gene_file{
    my ($self)    = shift;
    my %hash;
    my $filename = $self->gene2omim_file;
    open FILE, "< $filename" or $self->log->logdie("Cannot open $filename");
    
    foreach my $line (<FILE>){
	chomp($line);
	my ($hs_protein,$wbgene,$omim_gene,$omim_disease) = split /\t/,$line;
	    next unless($wbgene);
	foreach (($omim_gene,$omim_disease)){
	    next unless(defined $_);
	    $_ =~ s/.*://;
	   $hash{$_}{$wbgene}=$hs_protein if($_);
	}
    }
    close(FILE);
    return \%hash;
}

sub read_omim_file{
    my ($self)    = shift;
    my %hash;
    my $filename = $self->morbidmap_txt_file;
    open MORBIDMAP, "< $filename" or $self->log->logdie("Cannot open $filename");

    foreach my $line (<MORBIDMAP>){
	my ($disorder,$gene,$omim,$location) = split /\|/,$line;
	$hash{$omim} = $gene if($omim && $gene);
    }
    close(MORBIDMAP);
    return \%hash;
}

sub create_disease_file{
    my ($self,$hash,$mm_hash)    = @_;

    my $omim_txt_file = $self->omim_txt_file;
    my $disease_ace_file = $self->disease_ace_file;
    

    open OMIM, "<$omim_txt_file" or die "Cannot open $omim_txt_file";
    open OUT, "> $disease_ace_file" or die "Cannot open $disease_ace_file";

    my ($number,$title,$note);
    my @line_elements;
    foreach my $line (<OMIM>) {
	    chomp $line;
	    if ( $line eq "\*RECORD\*" ) {
		next unless $number;
		$title =~ s/^.*$number //;
		my @syn = split(";",$title);
		$title = shift @syn;
		print OUT qq{\nDisease : "$number"\n};
		print OUT qq{name\t"$title"\n};
		print OUT qq{Description\t"$note"\n};
	      
		foreach (@syn){
		  if($_){
		    s/^\s+|\s+$//g;
		    print OUT qq{synonym\t"$_"\n};
		  } 
		}
		if( $hash->{$number}){ #Todo: need to print Ensembl protein info as well
		  foreach my $key (sort keys %{$hash->{$number}}){
			  print OUT "Gene\t\"",$key,"\"\n";
		  }
		} 
		if( $mm_hash->{$number}){
		    foreach (split /, /,$mm_hash->{$number}){
			  print OUT "hsgene\t\"",$_,"\"\n";
		    }
		}
		($number,$title,$note)=('','','');
	    }
	    elsif ( $line =~ m/^\*FIELD\* NO/ ) {
		@line_elements=();
	    }
	    elsif ( $line =~ m/^\*FIELD\* TI/ ) {
		$number = join(' ',@line_elements);
		@line_elements=();
	    }
	    elsif ( $line =~ m/^\*FIELD\* TX/ ) {
		$title = join(' ',@line_elements);
		@line_elements=();
	    }
	    elsif ( $line =~ m/^\*FIELD\*/ ) {
		unless($note){
		$note = substr(join(' ',@line_elements),0,500);
		}
		@line_elements=();
	    }
	    else {
		    push @line_elements, $line;
	    }
	
    }
      
    close(OMIM);
    close(OUT);
}


1;

=cut
