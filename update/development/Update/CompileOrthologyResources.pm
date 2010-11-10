package Update::CompileOrthologyResources; #

use base 'Update';
use strict;
use Ace;

our $support_db_dir; # ".";
our $datadir;
our $disease_page_data_txt_file;
our $disease_search_data_txt_file;
our $full_disease_data_txt_file;
our $gene_association_file;
our $gene_id2go_bp_txt_file;
our $gene_id2go_mf_txt_file;
our $gene_id2omim_ids_txt_file;
our $gene_id2phenotype_txt_file;
our $go_id2omim_ids_txt_file;
our $hs_ensembl_id2omim_txt_file;
our $morbidmap_file;
our $omim_id2all_ortholog_data_txt_file;
our $omim_id2disease_desc_txt_file;
our $omim_id2disease_notes_txt_file;
our $omim_id2disease_name_txt_file;
our $omim_id2disease_synonyms_txt_file;
our $omim_id2disease_txt_file;
our $omim_id2go_ids_txt_file;
our $omim_id2phenotypes_txt_file;
our $omim_reconfigured_txt_file;
our $omim_txt_file;
our $ortholog_other_data_txt_file;
our $ortholog_other_data_hs_only_txt_file;
our $all_proteins_txt_file;
our $hs_proteins_txt_file;
our $DB;
our $omim_id2_gene_name_file;
our $precompile_data_dir;
our $ontology_dir;
our $onto_gene_association_file;
our $omim2disease_txt_file;

sub step {return 'compile interaction data';}

sub run{
	
	my $self = shift @_;
	my $release =  $self->release; #"WS207";
	
	### add control hash for each step here ####
	
	# TODO: add a way to turn each step on or off here vs. commenting them out which makes the script error prone .....
	
	### control hash ####
	
	
	##$DB = Ace->connect(-host=>'localhost',-port=>2005) or die "Cannot connect to Acedb"; 
	
	## datapaths and files

	$support_db_dir = $self->support_dbs;
	$precompile_data_dir = $support_db_dir . "/orthology_staging";
	$datadir = $support_db_dir."\/$release\/orthology";
	$ontology_dir = $support_db_dir."\/$release\/ontology";
	$onto_gene_association_file = "gene_association." . $release . ".wb.ce";
	
	$disease_page_data_txt_file = "$datadir/disease_page_data.txt";
	$disease_search_data_txt_file = "$datadir/disease_search_data.txt";
	$full_disease_data_txt_file = "$datadir/full_disease_data.txt";
	$gene_association_file = "$datadir/gene_association." . $release . ".wb.ce";
	$gene_id2go_bp_txt_file = "$datadir/gene_id2go_bp.txt";
	$gene_id2go_mf_txt_file = "$datadir/gene_id2go_mf.txt";
	$gene_id2omim_ids_txt_file =  "$datadir/gene_id2omim_ids.txt";
	$gene_id2phenotype_txt_file = "$datadir/gene_id2phenotype.txt";
	$go_id2omim_ids_txt_file =  "$datadir/go_id2omim_ids.txt";
	$hs_ensembl_id2omim_txt_file = "$datadir/hs_ensembl_id2omim.txt";
	$morbidmap_file = "$datadir/morbidmap";
	$omim_id2all_ortholog_data_txt_file = "$datadir/omim_id2all_ortholog_data.txt";
	$omim_id2disease_desc_txt_file = "$datadir/omim_id2disease_desc.txt";
	$omim_id2disease_notes_txt_file = "$datadir/omim_id2disease_notes.txt";
	$omim_id2disease_name_txt_file  =  "$datadir/omim_id2disease_name.txt";
	$omim_id2disease_synonyms_txt_file = "$datadir/omim_id2disease_synonyms.txt";
	$omim_id2disease_txt_file = "$datadir/omim_id2disease.txt";
	$omim_id2go_ids_txt_file =  "$datadir/omim_id2go_ids.txt";
	$omim_id2phenotypes_txt_file =  "$datadir/omim_id2phenotypes.txt";
	$omim_reconfigured_txt_file = "$datadir/omim_reconfigured.txt";
	$omim_txt_file = "$datadir/omim.txt";
	$ortholog_other_data_txt_file = "$datadir/ortholog_other_data.txt";
	$ortholog_other_data_hs_only_txt_file = "$datadir/ortholog_other_data_hs_only.txt";
	$all_proteins_txt_file = "$datadir/all_proteins.txt";
	$hs_proteins_txt_file = "$datadir/hs_proteins.txt";
	$omim_id2_gene_name_file = "$datadir/omim_id2gene_name.txt";
	$omim2disease_txt_file = "$datadir/omim2disease.txt";
	
	###################
	##### run #########
	###################

	### 20101108_main ####
	
	## get precompile data ##
	
#	print "obtaining precompile dataset";
#	$self->get_precompile_data();
#	print " -- OK\n";


	### end 20101108_main ####
#	
#	print "reconfiguring OMIM file"; 
#	$self->reconfigure_omim_file();  ## OK
#	print " -- OK\n";
#	
#	print "getting associated phenes";
#	$self->get_all_associated_phenotypes(); ## OK
#	print " -- OK\n";
# 
# 	print "pulling omim descriptions";
# 	$self->pull_omim_desc(); ## OK
#	print " -- OK\n";
#	
#	print "getting associated function go terms";
#	$self->get_all_associated_go_terms("F",$gene_id2go_mf_txt_file); # OK
#	print " -- OK\n";
#	
#	print "getting associated process go terms";
#  	$self->get_all_associated_go_terms("P",$gene_id2go_bp_txt_file); # OK
#	print " -- OK\n";
#
#	print "getting omim text notes";
#  	$self->pull_omim_txt_notes(); # OK
# 	print " -- OK\n";
#  	
#  	print "processing omim 2 disease data";
#  	$self->process_omim_2_disease_data(); ## OK
#  	print " -- OK\n";
#  	
#  	print "printing hs orthology other data";
#  	$self->print_hs_ortholog_other_data(); ## OK
#	print " -- OK\n";
#	
#	print "updating hs protein list";
#	$self->update_hs_protein_list(); ## OK
#	print " -- OK\n";
#
#	print "processing ensembl 2 omim data";
# 	$self->process_ensembl_2_omim_data(); ## needs work, pull data from Sanger Ace files if at all possible
# 	print " -- OK\n";
# 	
# 	print "assembling disease data";
# 	$self->assemble_disease_data(); ## OK
# 	print " -- OK\n";
#
#	print "printing disease page data";
#  	$self->print_disease_page_data(); ## OK
# 	print " -- OK\n";
#
#	print "processing omim 2 all ortholog data";
#	$self->process_pipe_delineated_file($disease_page_data_txt_file,1,"0-1-2-3-4-5-6-7-8-9-10-11-12",0,$omim_id2all_ortholog_data_txt_file); ## OK
# 	print " -- OK\n";
#  	
#  	print "getting disease synonyms";
#  	$self->pull_disease_synonyms(); ## OK
# 	print " -- OK\n";
# 	
# 	print "processing omim 2 phenotype";
# 	$self->process_pipe_delineated_file($disease_page_data_txt_file,1,'8',1,$omim_id2phenotypes_txt_file); ## OK
#	print " -- OK\n";
#	
#	print "processing omim 2 disease name";
#  	$self->process_pipe_delineated_file($disease_page_data_txt_file,1,'0',0,$omim_id2disease_name_txt_file ); ## OK
# 	print " -- OK\n";
#
#	print "processing gene 2 omim ids file";
# 	$self->process_pipe_delineated_file($disease_page_data_txt_file,2,'1',1,$gene_id2omim_ids_txt_file); ## OK
# 	print " -- OK\n";
# 	
# 	print "processing omim 2 go id file";
# 	$self->process_pipe_delineated_file($disease_page_data_txt_file,1,'9-10',1,$omim_id2go_ids_txt_file); ## OK
# 	print " -- OK\n";
#  	
#  	print "compiling omim go data";
#  	$self->compile_omim_go_data(); ## OK
# 	print " -- OK\n";
#
#	print "assembling search data";
# 	$self->assemble_search_data(); ## OK
# 	print " -- OK\n";
# 	
# 	print "processing omim 2 gene name"; 
# 	$self->process_omim_id2_gene_name(); ## OK
#	print " -- OK\n";
 	
	print "pushing out files for next release";
	$self->push_files_for_next_release();
	print " -- OK\n";


}

### $self->process_pipe_delineated_file(); template	

#################
## subroutines ##
#################


#### 20101108_sub ####

sub get_precompile_data {
	
	## get external, and data from last release	
	my $check_file = "get_precompile.chk";
	
	## system_call -- set up a template
	my $pull_extenal_data_command = "mv $precompile_data_dir/* $datadir";
	Update::system_call($pull_extenal_data_command,$check_file);
	
	## copy ontology data

	# id2name.txt
	my $copy_id2name_cmd = "cp $ontology_dir\/id2name.txt $datadir";
	Update::system_call($copy_id2name_cmd, $check_file);
	
	# name2id.txt
	my $copy_name2id_cmd = "cp $ontology_dir\/name2id.txt $datadir";
	Update::system_call($copy_name2id_cmd, $check_file);
	
	# gene_association file
	my $copy_gene_association_command = "cp $ontology_dir/$onto_gene_association_file $datadir";
	Update::system_call($copy_gene_association_command, $check_file);
	
	## unzip OMIM file
	my $unzip_cmd = "gunzip $datadir/omim.txt.Z";
	Update::system_call($unzip_cmd, $check_file);	
}


sub push_files_for_next_release {

	my @files_2_push = (
		$all_proteins_txt_file,
		$hs_proteins_txt_file
	);
	
	my $check_file = "file_push.chk";	
	my $cmd = "cp $omim_id2disease_txt_file $omim2disease_txt_file"; 
	Update::system_call($cmd, $check_file);
	
	foreach my $file (@files_2_push) {
		
		my $cmd = "cp $file $precompile_data_dir";
		Update::system_call($cmd, $check_file);
	}	
}

#### end 20101108_development ####


sub update_hs_protein_list {

	my $all_protein_list = $all_proteins_txt_file;
	my $hs_protein_list = $hs_proteins_txt_file;
	
	my $DB = Ace->connect(-host=>'localhost',-port=>2005);  ## 20101108 cleanup
	
	open ALL_PROTEIN_LIST, "$all_protein_list" or die "Cannot open all protein list\n";
	
	## build protein hash
	my %all_proteins;

	foreach my $protein_id (<ALL_PROTEIN_LIST>) {
	
		chomp $protein_id;
		$all_proteins{$protein_id} = 1;
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

### 20100201 addn

sub process_omim_id2_gene_name{

	my %gene_id2omim_ids = build_hash($gene_id2omim_ids_txt_file);
	my %omim_id2gene_ids;
	my $DB = Ace->connect(-host=>'localhost',-port=>2005) or die "Cannot connect to Acedb"; 
	## set up output file
	
	open OUT, ">$omim_id2_gene_name_file";

	foreach my $gene_id (keys %gene_id2omim_ids) {
		
		my $gene_obj;
		my $gene_cgc;
		my $gene_seq;
		my $omim_id_line; 
		my @omim_ids;
		

		$gene_obj = $DB->fetch(-class=>'Gene',-name=>$gene_id);
		
		eval {$gene_cgc = $gene_obj->CGC_name;};
		eval {$gene_seq = $gene_obj->Sequence_name;};
	
		$omim_id_line = 	$gene_id2omim_ids{$gene_id}; 
		@omim_ids = split "%", $omim_id_line;
			
		foreach my $omim_id (@omim_ids) {
		
			$omim_id2gene_ids{$omim_id}{$gene_cgc} = 1;
			$omim_id2gene_ids{$omim_id}{$gene_seq} = 1;
		}
	}
	
	foreach my $omim_id (keys %omim_id2gene_ids) {
	
		my $gene_ids = $omim_id2gene_ids{$omim_id};
		my @gene_ids = keys %$gene_ids;
		print OUT "$omim_id\=\>@gene_ids\n";
	} 
}


### end 20100201 addn ###



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

	my %go_id2omim_id;

	foreach my $omim_id (keys %omim_id2go_ids){
	
		my $go_ids = $omim_id2go_ids{$omim_id};
		$go_ids =~ s/\|/&/g;
		$go_ids =~ s/&&*/&/g;

		if($go_ids) {
			my @go_ids = split "&",$go_ids;
			foreach my $go_id (@go_ids){

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
	
	my ($self,$datafile,$key_index,$value_index_list,$multi,$outfile) = @_;
	my @value_indices = split "-",$value_index_list;
	my %recompiled_data;

	open DATAFILE, "< $datafile" or die "Cannot open $datafile";
	open OUT, "> $outfile" or die "Cannot open $outfile";
	
	foreach my $line (<DATAFILE>){
		chomp $line;
		my @line_elements = split /\|/, $line;
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
			}
		}
		
		else {
			$recompiled_data{$line_elements[$key_index]} = $value_line;
		}
	}

	foreach my $key (keys %recompiled_data){
		print OUT "$key\=\>$recompiled_data{$key}\n"; #
	}
	
}

sub print_disease_page_data{

	my $in_file = $full_disease_data_txt_file;
	my $out_file = $disease_page_data_txt_file;
	my $check_file = "print_disease_page_data.chk";
	my $grep_cmd = "grep -v NO_DISEASE $in_file > $out_file";
	Update::system_call($grep_cmd, $check_file);
	#open OUT, "> $out_file" or die "Cannot open $out_file";
	#my $data = ``;
	#print OUT $data;
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

	foreach my $line (<FILE>){
		my $disease;
		my $omim_id;

		chomp $line;
		my ($wb_id,$db,$ortholog_id,$sp,$analysis,$method) = split /\|/,$line;
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
	open FILE, "<$file_name" or die "Cannot open the file: $file_name\n";
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
		
		else {
		
			$line_elements[0] =~ s/[{*,}*]//g;
			$line_elements[0] =~ s/\[*//g;
			$line_elements[0] =~ s/\]*//g;
			print OUT "$line_elements[2]\=\>$line_elements[0]\n";
	   }
	}
}


sub process_ensembl_2_omim_data{
	
	my ($self) = @_;
	my $DB = Ace->connect(-host=>'localhost', -port=>2005) or die "Cannot open Acedb for process_ensembl_2_omim_data";  ## 20101108 clean up
	my $infile = $hs_proteins_txt_file;
	my $outfile = $hs_ensembl_id2omim_txt_file;
	
	open INFILE, "$infile" or die "Cannot open $infile\n";
	open OUTFILE, "> $outfile" or die "Cannot open $outfile\n";
	
	foreach my $object_name (<INFILE>){
	
		chomp $object_name;
		my $db_info;
		my @data;

		my $object = $DB->fetch(-class =>'Protein', -Name=>$object_name);
		eval {$db_info = $object->DB_info;}; ### end eval
		eval {@data = $db_info->col;}; 

		foreach my $db_data (@data){
		
			if($db_data =~ m/OMIM/){
				my @db_data;
				eval {@db_data = $db_data->col;}; 
					foreach my $omim_data (@db_data){
						if($omim_data =~ m/disease/){
							my $disease_id;
							eval {$disease_id = $omim_data->right;};
							my ($ensembl,$ensembl_id) = split /:/, $object_name;
							print OUTFILE "$ensembl_id\=\>"; # 
							print OUTFILE "$disease_id\n"; #
				
					} 
				
				}
				
			} ## end if ($db_data =~ m/OMIM/)
		} # end foreach my $db_data (@data)
	} # end foreach my $db_data (@data)
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
	
		my ($self) = @_;
		my $DB = Ace->connect(-host=>'localhost', -port=>2005) or die "Cannot connect to DB for get_all_ortholog_other_data"; 
		my $class = 'Gene';
		my $tag = 'Ortholog_other';
		my $host = 'aceserver.cshl.org';
		# my $host = 'brie3.cshl.org';
		# my $host = 'localhost';

	
		my $out_file = $ortholog_other_data_txt_file;
		open OUT, "> $out_file" or die "Cannot open $out_file\n";
		#my $aql_query = "select all class $class where exists_tag ->$tag";
		#my @objects_full_list = $DB->aql($aql_query);
		my @objects_full_list;

		my @genes = $DB->fetch(-class=>$class);
		foreach my $gene (@genes){

		    my @oo = $gene->Ortholog_other;
		    if (@oo) {
			
			push @objects_full_list, $gene;

		    } else {

			next;

		    }
		}
		

		# my @objects_test_list = $objects_full_list[10 .. 100];
		my %ortholog_db_counter;
		my $error_count = 0;
		foreach my $object (@objects_full_list) { #@objects_test_list 
		    eval{
		                #my $gene = shift @{$object};
				my $gene = $object;
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
	
	my ($self) = @_;
	my $DB = Ace->connect(-host=>'localhost', -port => 2005) or die "Cannot connect to DB for get_all_associated_phenotypes";
	
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
