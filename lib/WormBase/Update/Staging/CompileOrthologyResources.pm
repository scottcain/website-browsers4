package WormBase::Update::Staging::CompileOrthologyResource . pm;

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

sub run {
    my $self         = shift;
    my $datadir      = $self->datadir;
    my $release      = $self->release;
    my $ontology_dir = $self->ontology_datadir;

    my $disease_page_data_txt_file   = "$datadir/disease_page_data.txt";
    my $disease_search_data_txt_file = "$datadir/disease_search_data.txt";
    my $full_disease_data_txt_file   = "$datadir/full_disease_data.txt";
    my $gene_association_file =
      "$datadir/gene_association." . $release . ".wb.ce";
    my $gene_id2go_bp_txt_file      = "$datadir/gene_id2go_bp.txt";
    my $gene_id2go_mf_txt_file      = "$datadir/gene_id2go_mf.txt";
    my $gene_id2omim_ids_txt_file   = "$datadir/gene_id2omim_ids.txt";
    my $gene_id2phenotype_txt_file  = "$datadir/gene_id2phenotype.txt";
    my $go_id2omim_ids_txt_file     = "$datadir/go_id2omim_ids.txt";
    my $hs_ensembl_id2omim_txt_file = "$datadir/hs_ensembl_id2omim.txt";
    my $morbidmap_file              = "$datadir/morbidmap";
    my $omim_id2all_ortholog_data_txt_file =
      "$datadir/omim_id2all_ortholog_data.txt";
    my $omim_id2disease_desc_txt_file  = "$datadir/omim_id2disease_desc.txt";
    my $omim_id2disease_notes_txt_file = "$datadir/omim_id2disease_notes.txt";
    my $omim_id2disease_name_txt_file  = "$datadir/omim_id2disease_name.txt";
    my $omim_id2disease_synonyms_txt_file =
      "$datadir/omim_id2disease_synonyms.txt";
    my $omim_id2disease_txt_file     = "$datadir/omim_id2disease.txt";
    my $omim_id2go_ids_txt_file      = "$datadir/omim_id2go_ids.txt";
    my $omim_id2phenotypes_txt_file  = "$datadir/omim_id2phenotypes.txt";
    my $omim_reconfigured_txt_file   = "$datadir/omim_reconfigured.txt";
    my $omim_txt_file                = "$datadir/omim.txt";
    my $ortholog_other_data_txt_file = "$datadir/ortholog_other_data.txt";
    my $ortholog_other_data_hs_only_txt_file =
      "$datadir/ortholog_other_data_hs_only.txt";
    my $all_proteins_txt_file   = "$datadir/all_proteins.txt";
    my $hs_proteins_txt_file    = "$datadir/hs_proteins.txt";
    my $omim_id2_gene_name_file = "$datadir/omim_id2gene_name.txt";
    my $omim2disease_txt_file   = "$datadir/omim2disease.txt";

    $self->log->info("getting precompiled data");
    $self->get_precompile_data();
    $self->log->debug("get_precompile_data done");

    $self->log->info("reconfiguring OMIM file");
    $self->reconfigure_omim_file( $omim_txt_file, $omim_reconfigured_txt_file );
    $self->log->info("reconfiguring OMIM file done");

    $self->log->info("getting associated phenes");
    $self->get_all_associated_phenotypes($gene_id2phenotype_txt_file);
    $self->log->info("getting associated phenes done");

    $self->log->info("pulling omim descriptions");
    $self->pull_omim_desc();
    $self->log->info("pulling omim descriptions done");

    $self->log->info("getting associated function go terms");
    $self->get_all_associated_go_terms( "F", $gene_association_file,
        $gene_id2go_mf_txt_file );
    $self->log->info("getting associated function go terms done");

    $self->log->info("getting associated process go terms");
    $self->get_all_associated_go_terms( "P", $gene_association_file,
        $gene_id2go_bp_txt_file );
    $self->log->info("getting associated process go terms done");

    $self->log->info("getting omim text notes");
    $self->pull_omim_txt_notes( $omim_reconfigured_txt_file,
        $omim_id2disease_notes_txt_file );
    $self->log->info("getting omim text notes done");

    $self->log->info("processing omim 2 disease data");
    $self->process_omim_2_disease_data( $morbidmap_file,
        $omim_id2disease_txt_file );
    $self->log->info("processing omim 2 disease data done");

    $self->log->info("printing hs orthology other data");
    $self->print_hs_ortholog_other_data( $ortholog_other_data_txt_file,
        $ortholog_other_data_hs_only_txt_file );
    $self->log->info("printing hs orthology other data done");

    $self->log->info("updating hs protein list");
    $self->update_hs_protein_list( $all_proteins_txt_file,
        $hs_proteins_txt_file );
    $self->log->info("updating hs protein list done");

    $self->log->info("processing ensembl 2 omim data");
    $self->process_ensembl_2_omim_data( $hs_proteins_txt_file,
        $hs_ensembl_id2omim_txt_file );
    $self->log->info("processing ensembl 2 omim data done");

    $self->log->info("assembling disease data");
    $self->assemble_disease_data( $ortholog_other_data_hs_only_txt_file,
        $full_disease_data_txt_file );
    $self->log->info("assembling disease data done");

    $self->log->info("printing disease page data");
    $self->print_disease_page_data( $full_disease_data_txt_file,
        $disease_page_data_txt_file );
    $self->log->info("printing disease page data done");

    $self->log->info("processing omim 2 all ortholog data");
    $self->process_pipe_delineated_file(
        $disease_page_data_txt_file,    1,
        '0-1-2-3-4-5-6-7-8-9-10-11-12', 0,
        $omim_id2all_ortholog_data_txt_file
    );
    $self->log->info("processing omim 2 all ortholog data done");

    $self->log->info("getting disease synonyms");
    $self->pull_disease_synonyms( $omim_txt_file,
        $omim_id2disease_synonyms_txt_file );
    $self->log->info("getting disease synonyms done");

    $self->log->info("processing omim 2 phenotype");
    $self->process_pipe_delineated_file( $disease_page_data_txt_file, 1, '8', 1,
        $omim_id2phenotypes_txt_file );
    $self->log->info("processing omim 2 phenotype done");

    $self->log->info("processing omim 2 go id file");
    $self->process_pipe_delineated_file( $disease_page_data_txt_file, 1, '9-10',
        1, $omim_id2go_ids_txt_file );
    $self->log->info("processing omim 2 go id file done");

    $self->log->info("compiling omim go data");
    $self->compile_omim_go_data( $omim_id2go_ids_txt_file,
        v $go_id2omim_ids_txt_file);
    $self->log->info("compiling omim go data done");

    $self->log->info("assembling search data");
    $self->assemble_search_data($disease_search_data_txt_file);
    $self->log->info("assembling search data done");

    $self->log->info("processing omim 2 gene name");
    $self->process_omim_id2_gene_name( $gene_id2omim_ids_txt_file,
        $omim_id2_gene_name_file );
    $self->log->info("processing omim 2 gene done");

    $self->log->info("pushing out files for next release");
    $self->push_files_for_next_release( $all_proteins_txt_file,
        $hs_proteins_txt_file );
    $self->log->info("pushing out files for next release done");
}

sub get_precompile_data {

    my ($self)             = shift;
    my $datadir            = $self->datadir;
    my $ontology_datadir   = $self->ontology_datadir;
    my $pc_datadir         = $self->precompile_datadir;
    my $precompile_datadir = "$pc_datadir/orthology_staging";

    ## get external, and data from last release
    my $check_file = "$datadir/get_precompile.chk";

    ## system_call -- set up a template
    my $pull_extenal_data_command = "mv $precompile_data_dir/* $datadir";
    $self->system_call( $pull_extenal_data_command, $check_file );

    ## copy ontology data

    # id2name.txt
    my $copy_id2name_cmd = "cp $ontology_datadir\/id2name.txt $datadir";
    $self->system_call( $copy_id2name_cmd, $check_file );

    # name2id.txt
    my $copy_name2id_cmd = "cp $ontology_datadir\/name2id.txt $datadir";
    $self->system_call( $copy_name2id_cmd, $check_file );

    # gene_association file
    my $copy_gene_association_command =
      "cp $ontology_datadir\/$onto_gene_association_file $datadir";
    $self->system_call( $copy_gene_association_command, $check_file );

    ## unzip OMIM file
    my $unzip_cmd = "gunzip $datadir/omim.txt.Z";
    $self->system_call( $unzip_cmd, $check_file );
}

sub reconfigure_omim_file {

    my $self      = shift;
    my $omim_file = shift;
    my $out_file  = shift;

    open OMIM, "< $omim_file" or $self->log->logdie("Cannot open $omim_file");
    open OUT,  "> $out_file"  or $self->log->logdie("Cannot open $out_file");

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

}

sub get_all_associated_phenotypes {

    my ( $self, $out_file ) = @_;
    my $class             = 'Gene';
    my $tag               = 'Phenotype';
    my $aql_query         = "select all class $class where exists_tag ->$tag";
    my @objects_full_list = $DB->aql($aql_query);

    open OUT, "> $out_file" or $self->log->logdie("Cannot open $out_file)";

    foreach my $object (@objects_full_list) {
        my $gene      = shift @{$object};
        my $gene_id   = $gene->name;
        my $phenotype = $gene->$tag;
        print OUT "$gene_id\=\>$phenotype\n";
    }

}

sub get_all_associated_go_terms {

    my ( $self, $aspect, $datafile, $outfile ) = @_
      ; ##  aspect: F,C, or P for molecular fucntion, cellelular component, and biological process respectively
    open DATAFILE, "< $datafile" or $self->log->logdie("Cannot open $datafile");
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

}

sub pull_omim_txt_notes {

    my $self        = shift;
    my $input_file  = shift;
    my $output_file = shift;

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

}

sub process_omim_2_disease_data {

    my $self     = shift;
    my $filename = shift;
    my $outfile  = shift;

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
}

sub print_hs_ortholog_other_data {
    my $self     = shift;
    my $in_file  = shift;
    my $out_file = shift;

    open OUT, "> $out_file" or $self->log->logdie("Cannot open $out_file");

    my $data = `grep sapiens $in_file`;
    print OUT $data;
}

sub update_hs_protein_list {

    my $self             = shift;
    my $all_protein_list = shift;
    my $hs_protein_list  = shift;

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
}

sub process_ensembl_2_omim_data {
    my ( $self, $infile, $outfile ) = @_;
    my $DB = $self->dbh;
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
}

sub assemble_disease_data {
    my $self     = shift;
    my $filename = shift;
    my $outfile  = shift;

    my %hs_gene_id2omim_id    = &build_hash($hs_ensembl_id2omim_txt_file);
    my %omim_id2disease       = &build_hash($omim_id2disease_txt_file);
    my %omim_id2disease_desc  = &build_hash($omim_id2disease_desc_txt_file);
    my %omim_id2disease_notes = &build_hash($omim_id2disease_notes_txt_file);
    my %gene_id2go_bp         = &build_hash($gene_id2go_bp_txt_file);
    my %gene_id2go_mf         = &build_hash($gene_id2go_mf_txt_file);
    my %gene_id2phenotype     = &build_hash($gene_id2phenotype_txt_file);

    open FILE, "< $filename" or $self->log->logdie("Cannot open $filename");
    open OUT,  "> $outfile"  or $self->log->logdie("Cannot open $outfile");

    foreach my $line (<FILE>) {
        my $disease;
        my $omim_id;

        chomp $line;
        my ( $wb_id, $db, $ortholog_id, $sp, $analysis, $method ) = split /\|/,
          $line;
        my $phenotype;
        my $functions;
        my $biological_processes;
        my %data;

        if ( $hs_gene_id2omim_id{$ortholog_id} ) {
            $omim_id = $hs_gene_id2omim_id{$ortholog_id};
        }

        else {
            $omim_id = "NO_OMIM";
        }

        if ( $omim_id2disease{$omim_id} ) {
            $disease = $omim_id2disease{$omim_id};
        }
        else {
            $disease = "NO_DISEASE";
        }

        print OUT
"$disease\|$omim_id\|$line\|$gene_id2phenotype{$wb_id}\|$gene_id2go_bp{$wb_id}\|$gene_id2go_mf{$wb_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\n";
    }

}

sub print_disease_page_data {
    my $self = shift my $in_file = shift;
    my $out_file   = shift;
    my $check_file = "print_disease_page_data.chk";
    my $grep_cmd   = "grep -v NO_DISEASE $in_file > $out_file";
    $self->system_call( $grep_cmd, $check_file );
}

sub process_pipe_delineated_file {
    ### arguments
    my ( $self, $datafile, $key_index, $value_index_list, $multi, $outfile ) =
      @_;
    my @value_indices = split "-", $value_index_list;
    my %recompiled_data;

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
    my ( $self, $omim_file, $outfile ) = @_;
    open OMIM, "<$omim_file" or $self->log->logdie("Cannot open $omim_file");
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
}

sub compile_omim_go_data {
    my ( $self, $omim_id2go_ids_txt_file, $outfile ) my %omim_id2go_ids =
      build_hash($omim_id2go_ids_txt_file);
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
}

sub assemble_search_data {
    my ( $self, $outfile ) = @_;
    my %omim2all_ortholog_data =
      build_hash($omim_id2all_ortholog_data_txt_file);
    my %omim2disease_name     = build_hash($omim_id2disease_name_txt_file);
    my %omim_id2disease_desc  = &build_hash($omim_id2disease_desc_txt_file);
    my %omim_id2disease_notes = &build_hash($omim_id2disease_notes_txt_file);
    my %omim_id2disease_synonyms =
      &build_hash($omim_id2disease_synonyms_txt_file);
    my %omim_id2phenotypes = &build_hash($omim_id2phenotypes_txt_file);

    open OUT, "> $outfile" or $self->log->logdie("Cannot open $outfile");

    foreach my $omim_id ( keys %omim2all_ortholog_data ) {
        print OUT
"$omim_id\|$omim2disease_name{$omim_id}\|$omim_id2disease_desc{$omim_id}\|$omim_id2disease_notes{$omim_id}\|$omim_id2disease_synonyms{$omim_id}\|$omim_id2phenotypes{$omim_id}\n";
    }
}

sub process_omim_id2_gene_name {
    my ( $self, $gene_id2omim_ids_txt_file, $omim_id2_gene_name_file ) = @_;
    my %gene_id2omim_ids = build_hash($gene_id2omim_ids_txt_file);
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
}

sub push_files_for_next_release {
    my ( $self, $all_proteins_txt_file, $hs_proteins_txt_file ) = @_;
    my @files_2_push = ( $all_proteins_txt_file, $hs_proteins_txt_file );

    my $check_file = "file_push.chk";
    my $cmd        = "cp $omim_id2disease_txt_file $omim2disease_txt_file";
    $self->system_call( $cmd, $check_file );

    foreach my $file (@files_2_push) {

        my $cmd = "cp $file $precompile_data_dir";
        $self->system_call( $cmd, $check_file );
    }
}

1;
