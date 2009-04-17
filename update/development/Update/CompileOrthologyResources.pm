package CompileOrthologyResources; #Update::

# use base 'Update';
use strict;
use Ace;

#### temp path variables for local mac development;

# our $dev_datadir = "./orthology_data/integration_test";  ## 
# 
# our $disease_page_data_txt_file = "$dev_datadir/disease_page_data.txt";
# our $disease_search_data_txt_file = "$dev_datadir/disease_search_data.txt";
# our $full_disease_data_txt_file = "$dev_datadir/full_disease_data.txt";
# our $gene_association_file = "$dev_datadir/gene_association.WS198.wb.ce";
# our $gene_id2go_bp_txt_file = "$dev_datadir/gene_id2go_bp.txt";
# our $gene_id2go_mf_txt_file = "$dev_datadir/gene_id2go_mf.txt";
# our $gene_id2omim_ids_txt_file =  "$dev_datadir/gene_id2omim_ids.txt";
# our $gene_id2phenotype_txt_file = "$dev_datadir/gene_id2phenotype.txt";
# our $go_id2omim_ids_txt_file =  "$dev_datadir/go_id2omim_ids.txt";
# our $hs_ensembl_id2omim_txt_file = "$dev_datadir/hs_ensembl_id2omim.txt";
# our $morbidmap_file = "$dev_datadir/morbidmap";
# our $omim_id2all_ortholog_data_txt_file = "$dev_datadir/omim_id2all_ortholog_data.txt";
# our $omim_id2disease_desc_txt_file = "$dev_datadir/omim_id2disease_desc.txt";
# our $omim_id2disease_notes_txt_file = "$dev_datadir/omim_id2disease_notes.txt";
# our $omim_id2disease_name_txt_file  =  "$dev_datadir/omim_id2disease_name.txt";
# our $omim_id2disease_synonyms_txt_file = "$dev_datadir/omim_id2disease_synonyms.txt";
# our $omim_id2disease_txt_file = "$dev_datadir/omim_id2disease.txt";
# our $omim_id2go_ids_txt_file =  "$dev_datadir/omim_id2go_ids.txt";
# our $omim_id2phenotypes_txt_file =  "$dev_datadir/omim_id2phenotypes.txt";
# our $omim_reconfigured_txt_file = "$dev_datadir/omim_reconfigured.txt";
# our $omim_txt_file = "$dev_datadir/omim.txt";
# our $ortholog_other_data_txt_file = "$dev_datadir/ortholog_other_data.txt";
# our $ortholog_other_data_hs_only_txt_file = "$dev_datadir/ortholog_other_data_hs_only.txt";
# 
# our $all_proteins_txt_file = "$dev_datadir/all_proteins.txt";
# our $hs_proteins_txt_file = "$dev_datadir/hs_proteins.txt";


#### end local stuff #####

sub step {return 'compile interaction data';}

sub run{
	
	my $self = shift @_;
	
	## brie_specific_: abstract
	my $release = "WS198"; #$self->release;
	
	### orthology dir should have been created
	
	## brie_specific_: 
	my $support_db_dir = "."; # $self->support_dbs;
	my $datadir = $support_db_dir."/orthology_data/$release"; # "/$release/orthology"
	
	## brie_specific_: -host=>'localhost'
	my $DB = Ace->connect(-host=>'localhost',-port=>2005); #'aceserver.cshl.org'
	
	## datapaths and files
	$self->disease_page_data_txt_file = ("$datadir/disease_page_data.txt");
	$self->disease_search_data_txt_file = ("$datadir/disease_search_data.txt");
	$self->full_disease_data_txt_file = ("$datadir/full_disease_data.txt)";
	$self->gene_association_file = ("$datadir/gene_association\.".$release."\.wb.ce");
	$self->gene_id2go_bp_txt_file = ("$datadir/gene_id2go_bp.txt");
	$self->gene_id2go_mf_txt_file = ("$datadir/gene_id2go_mf.txt");
	$self->gene_id2omim_ids_txt_file =  ("$datadir/gene_id2omim_ids.txt");
	$self->go_id2omim_ids_txt_file =  ("$datadir/go_id2omim_ids.txt");
	$self->hs_ensembl_id2omim_txt_file = ("$datadir/hs_ensembl_id2omim.txt");
	$self->morbidmap_file = ("$datadir/$morbidmap");
	$self->omim_id2all_ortholog_data_txt_file = ("$datadir/omim_id2all_ortholog_data.txt");
	$self->omim_id2disease_desc_txt_file("$datadir/$omim_id2disease_desc.txt");
	$self->omim_id2disease_notes_txt_file = ("$datadir/omim_id2disease_notes.txt");
	$self->omim_id2disease_name_txt_file  =  ("$datadir/omim_id2disease_name.txt");
	$self->omim_id2disease_synonyms_txt_file = ("$datadir/omim_id2disease_synonyms.txt");
	$self->omim_id2go_ids_txt_file =  ("$datadir/omim_id2go_ids.txt");
	$self->omim_id2phenotypes_txt_file =  ("$datadir/omim_id2phenotypes.txt");
	$self->omim_reconfigured_txt_file("$datadir/omim_reconfigured.txt");
	$self->omim_txt_file("$datadir/omim.txt");
	$self->ortholog_other_data_txt_file = ("$datadir/ortholog_other_data.txt");
	$self->ortholog_other_data_hs_only_txt_file = "($datadir/ortholog_other_data_hs_only.txt)";
	$self->gene_id2phenotype_txt_file("$datadir/gene_id2phenotype.txt");
	$self->omim_id2disease_txt_file = ("$datadir/omim_id2disease.txt");
	$self->$all_proteins_txt_file = ("$dev_datadir/all_proteins.txt");
	$self->$hs_proteins_txt_file = ("$dev_datadir/hs_proteins.txt");
 	
	## run ##

	#$self->compile_external_files();
	#$self->reconfigure_omim_file();  ## OK
	#$self->get_all_associated_phenotypes($DB); ## OK
	# $self->pull_omim_desc(); ## OK
	# $self->get_all_ortholog_other_data($DB); ## works but needs another plan to pull ortholog_other data -- probably from the ace files...
	# $self->get_all_associated_go_terms("F",$gene_id2go_mf_txt_file); # OK
	# $self->get_all_associated_go_terms("P",$gene_id2go_bp_txt_file); # OK
	# $self->pull_omim_txt_notes(); # OK
	# $self->process_omim_2_disease_data(); ## OK
	# $self->print_hs_ortholog_other_data(); ## OK
	
	# $self->update_hs_protein_list(); ## OK
	
	# $self->process_ensembl_2_omim_data($DB); ## needs work, pull data from Sanger Ace files if at all possible
	
	
	
	# $self->assemble_disease_data(); ## OK
	# $self->print_disease_page_data(); ## OK
	#$self->process_pipe_delineated_file($disease_page_data_txt_file,1,"0-1-2-3-4-5-6-7-8-9-10-11-12",0,$omim_id2all_ortholog_data_txt_file); ## OK
	
	# $self->pull_disease_synonyms(); ## OK
	 #$self->process_pipe_delineated_file($disease_page_data_txt_file,1,'8',1,$omim_id2phenotypes_txt_file); ## OK
	# $self->process_pipe_delineated_file($disease_page_data_txt_file,1,'0',0,$omim_id2disease_name_txt_file ); ## OK
	#$self->process_pipe_delineated_file($disease_page_data_txt_file,2,'1',1,$gene_id2omim_ids_txt_file); ## OK
	#$self->process_pipe_delineated_file($disease_page_data_txt_file,1,'9-10',1,$omim_id2go_ids_txt_file); ## OK
	# $self->compile_omim_go_data(); ## OK
	 $self->assemble_search_data(); ## OK
}
	# $self->process_pipe_delineated_file(); template
############################
## subroutines ##


sub compile_external_files {

system ('cp /usr/local/wormbase-devel/norie/databases/pipeline/WS199/orthology/* /usr/local/wormbase-devel/norie/orthology_compile/orthology_data/integration_test');

system ('cp /usr/local/wormbase-devel/norie/databases/pipeline/WS199/ontology/* /usr/local/wormbase-devel/norie/orthology_compile/orthology_data/integration_test');

}


sub update_hs_protein_list {

	my $all_protein_list = $all_proteins_txt_file;
	my $hs_protein_list = $hs_proteins_txt_file;


open ALL_PROTEIN_LIST, "$all_protein_list" or die "Cannot open all protein list\n";

my $DB = Ace->connect(-host=>'aceserver.cshl.org',-port=>2005);


## build protein hash

my %all_proteins;

foreach my $protein_id (<ALL_PROTEIN_LIST>) {
	
	chomp $protein_id;
	$all_proteins{$protein_id} = 1;
#	print "$protein_id\n";

}

close ALL_PROTEIN_LIST;

open ALL_PROTEIN_LIST, ">>$all_protein_list" or die "Cannot open all protein list\n";
open HS_PROTEIN_LIST, ">>$hs_protein_list" or die "Cannot open hs protein list\n";

### get and check protein data 


my @acedb_proteins = $DB->fetch(-class=>'Protein');

foreach my $ace_protein (@acedb_proteins) {

	if ($all_proteins{$ace_protein}) {
	
		next;
	
	} else {
	
			#print "$ace_protein\n";
		 	my $sp = $ace_protein->Species;
                
        	if($sp =~ m/sapien/){
             
             	print ALL_PROTEIN_LIST "$ace_protein\n";
             	print HS_PROTEIN_LIST "$ace_protein\n";
             
             } else {
               
               	print ALL_PROTEIN_LIST "$ace_protein\n";
                
           	}


	}
}




}

sub assemble_search_data{
	
	my $outfile = $disease_search_data_txt_file;
	open OUT, "> $outfile" or die "Cannot open $outfile\n";
	
	my %omim2all_ortholog_data = build_hash($omim_id2all_ortholog_data_txt_file);
	my %omim2disease_name = build_hash($omim_id2disease_name_txt_file);
	my %omim_id2disease_desc = &build_hash($omim_id2disease_desc_txt_file);
	my %omim_id2disease_notes = &build_hash($omim_id2disease_notes_txt_file);
	my %omim_id2disease_synonyms = &build_hash($omim_id2disease_synonyms_txt_file);
	my %omim_id2phenotypes = &build_hash($omim_id2phenotypes_txt_file);


	foreach my $omim_id (keys %omim2all_ortholog_data){
		print OUT "$omim_id\|$omim2disease_name{$omim_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\|$omim_id2disease_synonyms{$omim_id}\|$omim_id2phenotypes{$omim_id}\n";
	}
	
}

sub compile_omim_go_data{
	
	my %omim_id2go_ids = build_hash($omim_id2go_ids_txt_file);
	my $outfile = $go_id2omim_ids_txt_file;

	open OUT, "> $outfile" or die "Cannot open $outfile\n";

	# my %omim_id2go_id;
	my %go_id2omim_id;

	foreach my $omim_id (keys %omim_id2go_ids){
		my $go_ids = $omim_id2go_ids{$omim_id};
		# print "1\: $terms\n";
		$go_ids =~ s/\|/&/g;
		$go_ids =~ s/&&*/&/g;
		# print "2\: $terms\n";
		if($go_ids) {
			my @go_ids = split "&",$go_ids;
			foreach my $go_id (@go_ids){
				# my $go_id = $name2id{$term};
				# $omim_id2go_id{$omim_id}{$go_id} = 1;
				$go_id2omim_id{$go_id}{$omim_id} = 1;
			}
		}

	}

	# my %go_id2omim_ids;

	foreach my $go_id (keys %go_id2omim_id){
		if($go_id) {
			print OUT "$go_id\=\>";
			my $omim_id_hr = $go_id2omim_id{$go_id};

			my $omim_id_line = join "|", keys %{$omim_id_hr};
			print OUT "$omim_id_line\n";
		}
		else{
			next;
		}

	}

}


sub pull_disease_synonyms {
	
	# my $omim_file = $ARGV[0];

	my ($self) = @_;

	my $omim_file = $omim_txt_file;
	my $outfile = $omim_id2disease_synonyms_txt_file;

	open OMIM,"<$omim_file" or die "Cannot open $omim_file\n";
	open OUT,"> $outfile" or die "Cannot open outfile\n";


	my $header;
	my @line_elements;
	my @lines;

	foreach my $line (<OMIM>){
		chomp $line;
		if(!($line =~ m/^*./)){
			next;
		}
		elsif($line eq "\*RECORD\*"){
			my $hold_line = $header."=>".(join " ",@line_elements);
			push @lines, $hold_line;
			push @lines, "$line";
			@line_elements = ();
		}	
		elsif($line =~ m/^\*FIELD\*/){
			my $hold_line = $header."=>".(join " ",@line_elements);
			push @lines, $hold_line;
			# push @lines, "$line\n";
			$header = $line;
			@line_elements = ();
		}
		else {
			push @line_elements, $line
		}
	}

	foreach my $output_line (@lines){
		if($output_line =~ m/MOVED/){
			next;
		}
		elsif($output_line =~ m/^\*FIELD\*\ TI/){
			if($output_line =~ m/MOVED/){
				next;
			}
			else{
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
}

sub process_pipe_delineated_file{
	
	### arguments

	# my $datafile = $ARGV[0]; ## file containing the data in rows
	# my $key_index = $ARGV[1]; ## index of the element (starting with zero) to be used as the key to the data hash to be created
	# my $value_index_list = $ARGV[2];  ### comma deliniated list of integers
	# my $multi = $ARGV[3];  ##  0 or 1


	####
	
	my ($self,$datafile,$key_index,$value_index_list,$multi,$outfile) = @_;

	my @value_indices = split "-",$value_index_list;
	#my $join_delineator = $delineator;
	#$join_delineator =~ s/\\//;
	my %recompiled_data;

	open DATAFILE, "< $datafile" or die "Cannot open $datafile";
	open OUT, "> $outfile" or die "Cannot open $outfile";
	
	foreach my $line (<DATAFILE>){
		chomp $line;
		# print "$line\n";
		my @line_elements = split /\|/, $line;
		# print "LE\: $line_elements[$key_index]\n";
		my $value = $recompiled_data{$line_elements[$key_index]};
		my @value_line;
		foreach my $value_index (@value_indices){
			push @value_line, $line_elements[$value_index];		
		}
		my $value_line = join "|",@value_line;

		if($value && $multi){
			if($value_line =~ m/$value/) {
				next;
			}
			else {
				$recompiled_data{$line_elements[$key_index]} = join '%',($value,$value_line);
				# print "ACTION:append\n";
			}
		}
		else {
			$recompiled_data{$line_elements[$key_index]} = $value_line;
			# print "ACTION:new\n";
		}
	}

	foreach my $key (keys %recompiled_data){
		print OUT "$key\=\>$recompiled_data{$key}\n"; #
	}
	
}

sub print_disease_page_data{
	my $in_file = $full_disease_data_txt_file;
	my $out_file = $disease_page_data_txt_file;
	
	open OUT, "> $out_file" or die "Cannot open $out_file";
	
	my $data = `grep -v  NO_DISEASE $in_file`;
	print OUT $data;
}

sub assemble_disease_data{
	
	my %hs_gene_id2omim_id = &build_hash($hs_ensembl_id2omim_txt_file);
	my %omim_id2disease = &build_hash($omim_id2disease_txt_file);
	my %omim_id2disease_desc = &build_hash($omim_id2disease_desc_txt_file);
	my %omim_id2disease_notes = &build_hash($omim_id2disease_notes_txt_file);
	my %gene_id2go_bp = &build_hash($gene_id2go_bp_txt_file);
	my %gene_id2go_mf = &build_hash($gene_id2go_mf_txt_file);
	my %gene_id2phenotype = &build_hash($gene_id2phenotype_txt_file);
	my $filename = $ortholog_other_data_hs_only_txt_file;
	my $outfile = $full_disease_data_txt_file;

	open FILE, "< $filename" or die "Cannot open $filename\n";
	open OUT, "> $outfile" or die "Cannot open $outfile\n";
	# my $DB = Ace->connect(-host=>'aceserver.cshl.org', -port=>2005);

	foreach my $line (<FILE>){
		my $disease;
		my $omim_id;

		chomp $line;
		my ($wb_id,$db,$ortholog_id,$sp,$analysis,$method) = split /\|/,$line;
		# print "$ortholog_id\n";
		my $phenotype;
		my $functions;
		my $biological_processes;
		my %data;
		if($hs_gene_id2omim_id{$ortholog_id}){
			$omim_id = $hs_gene_id2omim_id{$ortholog_id};
		}
		else {
			$omim_id = "NO_OMIM";
		}

		if($omim_id2disease{$omim_id}){
			$disease = $omim_id2disease{$omim_id};
		}
		else{
			$disease = "NO_DISEASE";
		}


		print OUT "$disease\|$omim_id\|$line\|$gene_id2phenotype{$wb_id}\|$gene_id2go_bp{$wb_id}\|$gene_id2go_mf{$wb_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\n";
	}
	
}

sub build_hash{
	my ($file_name) = @_;
	open FILE, "<./$file_name" or die "Cannot open the file: $file_name\n";
	my %hash;
	foreach my $line (<FILE>) {
		chomp ($line);
		my ($key, $value) = split '=>',$line;
		$hash{$key} = $value;
	}
	return %hash;
}


sub print_hs_ortholog_other_data {
	
	my $in_file = $ortholog_other_data_txt_file;
	my $out_file = $ortholog_other_data_hs_only_txt_file;
	
	open OUT, "> $out_file" or die "Cannot open $out_file";
	
	my $data = `grep sapiens $in_file`;
	print OUT $data;
}

sub process_omim_2_disease_data{

	my $filename = $morbidmap_file;
	my $outfile = $omim_id2disease_txt_file;

	open FILE,"< $filename" or die "Cannot open $filename\n";
	open OUT, "> $outfile" or die "Cannot open $outfile\n";
	foreach my $line (<FILE>){
	        chomp $line;
	        my @line_elements = split '\|',$line;
	        $line_elements[0] =~ s/\(.\)//g;
	        if ($line_elements[0] =~ m/[0-9]{6}/){
	                my @disease_data = split ",",$line_elements[0];
	                my $omim_id = pop @disease_data;
	                $omim_id =~ s/ //g;
	                my @disease_names;
	                foreach my $disease_datum (@disease_data){
	                        $disease_datum =~ s/[{*,}*]//g;
	                        $disease_datum =~ s/\[*//g;
	                        $disease_datum =~ s/\]*//g;
	                        push @disease_names, $disease_datum;
	                }
	                my $disease_name = join ",",@disease_names;
	                print OUT "$omim_id\=\>$disease_name\n";
	        }
	        else{
	                $line_elements[0] =~ s/[{*,}*]//g;
	                $line_elements[0] =~ s/\[*//g;
	                $line_elements[0] =~ s/\]*//g;
	                print OUT "$line_elements[2]\=\>$line_elements[0]\n";
	        }


	}
	
}


sub process_ensembl_2_omim_data{
	
	my ($self,$DB) = @_;
	
	my $infile = $hs_proteins_txt_file;
	my $outfile = $hs_ensembl_id2omim_txt_file;
	
	open INFILE, "$infile" or die "Cannot open $infile\n";
	open OUTFILE, "> $outfile" or die "Cannot open $outfile\n";
	
	foreach my $object_name (<INFILE>){
	
	chomp $object_name;

		
		    eval {

		    my $object = $DB->fetch(-class =>'Protein', -Name=>$object_name);
		    my $db_info = $object->DB_info;
		    my @data = $db_info->col;
			# print "@data\n";
			foreach my $db_data (@data){
			
				if($db_data =~ m/OMIM/){
				
					my @db_data = $db_data->col;
						foreach my $omim_data (@db_data){
							if($omim_data =~ m/disease/){
								my $disease_id = $omim_data->right;
								my ($ensembl,$ensembl_id) = split /:/, $object_name;
								print OUTFILE "$ensembl_id\=\>"; # 
								print OUTFILE "$disease_id\n"; #
					
						} 
					
					}
					
				} ## end if ($db_data =~ m/OMIM/)
			
			    } # end foreach my $db_data (@data)
	
		} ### end eval
#	} # end else
		
}

}
	

sub pull_omim_txt_notes{
	
	my $self = shift @_;
	my $input_file = $omim_reconfigured_txt_file; 
	my $output_file = $omim_id2disease_notes_txt_file;

	open OMIM,"< $input_file" or die "Cannot open $input_file\n";
	open OUT, "> $output_file" or die "Cannot open $output_file\n";
	
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
	                if(!($desc eq '<br>')){
	                        print OUT "$id\=\>$desc\n";
	                }
	                undef $id;
	                undef $desc;
	        }       
	        elsif($line =~ m/^\*FIELD\*\ NO/){
	                ($discard,$id) = split /\=\>/,$line;
	                $id =~ s/<br>//;
	        }
	        elsif($line =~ m/^\*FIELD\*\ TX/){
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
	
}

sub get_all_associated_go_terms{
	
	my ($self,$aspect,$outfile) = @_;##  aspect: F,C, or P for molecular fucntion, cellelular component, and biological process respectively
	
	my $datafile = $gene_association_file;

	open DATAFILE, "< $datafile" or die "Cannot open $datafile";
	open OUT, "> $outfile" or die "Cannot open $outfile";

	my %data_hash;

	foreach my $line (<DATAFILE>){
	        chomp $line;
	        # print "$line\n";
	        my @line_elements = split /\t/, $line;
	        # print "LE: $line_elements[1]\|$line_elements[4]\|$line_elements[8]\n";
	        $data_hash{$line_elements[1]}{$line_elements[8]}{$line_elements[4]} = 1;        
	}

	foreach my $go_id (keys %data_hash){
	        my $go_terms_hr = $data_hash{$go_id}{$aspect};
	        if($go_terms_hr){
	                my $term_list = join "&", (keys %{$go_terms_hr});
	                print OUT "$go_id\=\>$term_list\n";
	        }
	        else{
	                next;
	        }
	}
	
}


sub get_all_ortholog_other_data {
	
		my ($self,$DB) = @_;
		my $class = 'Gene';
		my $tag = 'Ortholog_other';
		my $host = 'aceserver.cshl.org';
		# my $host = 'brie3.cshl.org';
		# my $host = 'localhost';

	
		my $out_file = $ortholog_other_data_txt_file;
		open OUT, "> $out_file" or die "Cannot open $out_file\n";

		my $aql_query = "select all class $class where exists_tag ->$tag";
		my @objects_full_list = $DB->aql($aql_query);
		# my @objects_test_list = $objects_full_list[10 .. 100];
		my %ortholog_db_counter;
		my $error_count = 0;
		foreach my $object (@objects_full_list) { #@objects_test_list 
		    eval{
		                my $gene = shift @{$object};
		                my @ortholog_others = $gene->Ortholog_other;
		                foreach my $ortholog_other (@ortholog_others){
		                        my $method = $ortholog_other->right(2);
		                        my $protein_id = $ortholog_other->DB_info->right(3);
		                        my $db = $ortholog_other->DB_info->right;
		                        my $fa = "From_analysis";
		                        my $species = $ortholog_other->Species;
		                        print OUT "$gene\|$db\|$protein_id\|$species\|$fa\|$method\n";
		                }
		            };

		}

		# print "$error_count\n";
		
}


sub pull_omim_desc{
	my $self = shift @_;
	my $omim_file = $omim_reconfigured_txt_file;
	my $out_file = $omim_id2disease_desc_txt_file;
	
	open OMIM,"< $omim_file" or die "Cannot open $omim_file\n";
	open OUT, "> $out_file" or die "Cannot open $out_file\n";
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
	
}

sub reconfigure_omim_file {
	
	my $self = shift @_;

	my $omim_file =  $omim_txt_file; #$self->omim_txt_file;
	my $out_file =  $omim_reconfigured_txt_file; #$self->omim_reconfigured_txt_file;
	
	open OMIM,"< $omim_file" or die "Cannot open $omim_file\n";
	open OUT, "> $out_file" or die "Cannot open $out_file\n";

	my $header;
	my @line_elements;

	foreach my $line (<OMIM>){
	        chomp $line;
	        # if(!($line =~ m/^*./)){
	        #       next;
	        # }
	        if($line eq "\*RECORD\*"){
	                # chomp $line;
	                print OUT "$header\=>";
	                print OUT (join " ",@line_elements);
	                print OUT "\n";
	                print OUT "$line\n";
	                @line_elements = ();
	        }       
	        elsif($line =~ m/^\*FIELD\*/){
	                # chomp $line;
	                print OUT "$header\=>";
	                print OUT (join " ",@line_elements);
	                print OUT "\n";
	                $header = $line;
	                @line_elements = ();

	        }
	        elsif($line =~ m/^[A-Z\s]*$/){
	                if(!($line =~ m/^*./)){
	                        push @line_elements, "$line\<br>";
	                }
	                else{
	                        # chomp $line;
	                        print OUT "$header\=>";
	                        print OUT (join " ",@line_elements);
	                        print OUT "\n";
	                        $header = "*".$line;
	                        @line_elements = ();
	                }               
	        }
	        else {
	                push @line_elements, "$line";
	        }
	}
	
}

sub get_all_associated_phenotypes {
	
	my ($self,$DB) = @_;
	
	my $class = 'Gene';
	my $tag = 'Phenotype';
	my $aql_query = "select all class $class where exists_tag ->$tag";
	my @objects_full_list = $DB->aql($aql_query);
	
	my $out_file = $gene_id2phenotype_txt_file; #self->gene_id2phenotype_txt_file;
	open OUT, "> $out_file" or die "Cannot open $out_file\n";
	
	foreach my $object (@objects_full_list) {
	    my $gene = shift @{$object};
	    my $gene_id = $gene->name;
	    my $phenotype = $gene->$tag;
	    print OUT "$gene_id\=\>$phenotype\n";                       
	}
	
}

1;
