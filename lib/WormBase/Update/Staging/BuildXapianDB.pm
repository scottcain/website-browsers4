package WormBase::Update::Staging::BuildXapianDB;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'building xapian database',
);

sub run {
    my $self = shift;       
    my $release = $self->release;
    $self->log->info("creating xapian database");
    my $tmp_dir = "/usr/local/wormbase/tmp/staging/$release/acedmp";
    system("mkdir -p $tmp_dir");
    system("chmod 777 $tmp_dir");
#    $self->dump_objects_via_tace($tmp_dir);    
    $self->dump_settings_file($tmp_dir);
    $self->dump_pages_pseudo_ace_file($tmp_dir);

    $self->run_indexer($tmp_dir);
    $self->log->info("done creating xapian database");
}

sub run_indexer {
    my ($self,$tmp_dir) = @_;
    my $release = $self->release;
    $self->log->info("   --> begin indexing xapian database");
    $self->system_call("/usr/local/wormbase/website-admin/update/staging/xapian/aceindex.local $tmp_dir/settings.conf $release");
    $self->log->info("   --> finished indexing xapian database");
}

sub dump_objects_via_tace {
    my $self = shift;
    my $tmp_dir = shift;
    my $version = $self->release;
    $self->log->info("   --> dumping ace files for indexing");
    open OUT,">$tmp_dir/dump_ace_for_search.script";
    print OUT <<END;
//tace script to dump database
Find Analysis
Write $tmp_dir/Analysis.ace
Find Anatomy_term
Write $tmp_dir/Anatomy_term.ace
Find Antibody
Write $tmp_dir/Antibody.ace
Find CDS
Write $tmp_dir/CDS.ace
Find Clone
Write $tmp_dir/Clone.ace
Find Expr_pattern
Write $tmp_dir/Expr_pattern.ace
Find Expr_profile
Write $tmp_dir/Expr_profile.ace
Find Expression_cluster
Write $tmp_dir/Expression_cluster.ace
Find Feature
Write $tmp_dir/Feature.ace
Find Gene
Write $tmp_dir/Gene.ace
Find Gene_class
Write $tmp_dir/Gene_class.ace
Find Gene_cluster
Write $tmp_dir/Gene_cluster.ace
Find Gene_regulation
Write $tmp_dir/Gene_regulation.ace
Find GO_code
Write $tmp_dir/GO_code.ace
Find GO_term
Write $tmp_dir/GO_term.ace
Find Homology_group
Write $tmp_dir/Homology_group.ace
Find Interaction
Write $tmp_dir/Interaction.ace
Find Laboratory
Write $tmp_dir/Laboratory.ace
Find Life_stage
Write $tmp_dir/Life_stage.ace
Find LongText
Write $tmp_dir/LongText.ace
Find Microarray_results
Write $tmp_dir/Microarray_results.ace
Find Molecule
Write $tmp_dir/Molecule.ace
Find Motif
Write $tmp_dir/Motif.ace
Find Oligo
Write $tmp_dir/Oligo.ace
Find Oligo_set
Write $tmp_dir/Oligo_set.ace
Find Operon
Write $tmp_dir/Operon.ace
Find Paper
Write $tmp_dir/Paper.ace
Find PCR_product
Write $tmp_dir/PCR_product.ace
Find Person
Write $tmp_dir/Person.ace
Find Phenotype
Write $tmp_dir/Phenotype.ace
Find Picture
Write $tmp_dir/Picture.ace
Find Position_matrix
Write $tmp_dir/Position_matrix.ace
Find Protein
Write $tmp_dir/Protein.ace
Find Pseudogene
Write $tmp_dir/Pseudogene.ace
Find Rearrangement
Write $tmp_dir/Rearrangement.ace
Find RNAi
Write $tmp_dir/RNAi.ace
Find Sequence
Write $tmp_dir/Sequence.ace
Find Strain
Write $tmp_dir/Strain.ace
Find Structure_data
Write $tmp_dir/Structure_data.ace
Find Transcript
Write $tmp_dir/Transcript.ace
Find Transgene
Write $tmp_dir/Transgene.ace
Find Transposon
Write $tmp_dir/Transposon.ace
Find Variation
Write $tmp_dir/Variation.ace
Find WBProcess
Write $tmp_dir/WBProcess.ace
END
;

    system("/usr/local/wormbase/acedb/bin/tace /usr/local/wormbase/acedb/wormbase_$version < $tmp_dir/dump_ace_for_search.script");
    close OUT;
}


sub dump_settings_file {
    my ($self,$tmp_dir) = @_;
    $self->log->info("   --> dumping settings file");
    my $release = $self->release;
    open OUT,">$tmp_dir/settings.conf";
    print OUT <<END;
acedump = "/usr/local/wormbase/tmp/staging/$release/acedmp";
search = "/usr/local/wormbase/databases";

classes = (   { filename = "Paper.ace";
                desc = ("author", "title", "journal", "page", "volume"); 
                after = "LongText.ace"; }, 
              { filename = "Gene.ace";
                desc = ("concise_description"); },
              { filename = "Variation.ace";
                desc = ("status", "gene", "remark"); },
              { filename = "Anatomy_term.ace";},
              { filename = "Antibody.ace";
                desc = ("gene", "remark"); },
              { filename = "Clone.ace"; },
              { filename = "CDS.ace"; },
              { filename = "Expression_cluster.ace"; 
                desc = ("description", "remark", "algorithm"); },
              { filename = "Expr_pattern.ace"; },
              { filename = "Expr_profile.ace"; },
              { filename = "Feature.ace"; },
              { filename = "Gene_cluster.ace";
                desc = ("description", "gene"); },
              { filename = "Gene_regulation.ace"; },
              { filename = "GO_term.ace"; },
              { filename = "Homology_group.ace"; },
              { filename = "Interaction.ace";
                desc = ("interactor", "remark"); },
              { filename = "Life_stage.ace"; },
              { filename = "Microarray_results.ace";
                desc = ("gene", "cds", "remark"); },
              { filename = "Molecule.ace"; },
              { filename = "Operon.ace"; 
                desc = ("gene", "remark", "description"); },
              { filename = "Position_matrix.ace"; },
              { filename = "PCR_product.ace"; },
              { filename = "Oligo.ace"; },
              { filename = "Oligo_set.ace"; },
              { filename = "Phenotype.ace"; },
              { filename = "Protein.ace"; 
                desc = ("corresponding_cds", "remark", "description"); },
              { filename = "Rearrangement.ace"; 
                desc = ("mutagen", "remark"); },
              { filename = "RNAi.ace"; },
              { filename = "Sequence.ace"; },
              { filename = "Strain.ace"; 
                desc = ("genotype", "remark"); },
              { filename = "Structure_data.ace"; },
              { filename = "Transgene.ace"; },
              { filename = "Transcript.ace"; },
              { filename = "Transposon.ace"; },
              { filename = "Analysis.ace"; 
                desc = ("title", "description"); },
              { filename = "Gene_class.ace"; },
              { filename = "Laboratory.ace"; 
                desc = ("representative", "mail", "remark"); },
              { filename = "Motif.ace"; },
              { filename = "Person.ace"; 
                desc = ("institution"); },
              { filename = "Disease.ace"; 
                desc = ("description", "gene", "hsgene", "synonym"); },
              { filename = "Widgets.ace"; 
                desc = ("widget_title", "editor", "wbid", "widget_order", "type"); },
              { filename = "WBProcess.ace"; },
              { filename = "Pages.ace"; 
                desc = ("description"); }        

          );

species = ( { name = "c_elegans";
              id = 6239; },
            { name = "c_angaria";
              id = 96668;
              gff3 = 1; },
            { name = "c_brenneri";
              id = 135651; },
            { name = "c_briggsae";
              id = 6238; },
            { name = "c_japonica";
              id = 281687; },
            { name = "c_remanei";
              id = 31234; },
            { name = "p_pacificus";
              id = 54126; },
            { name = "a_sum";
              id = 6253; },
            { name = "b_malayi";
              id = 6279; 
              gff3 = 1; },
            { name = "c_sp11";
              id = 886184; 
              gff3 = 1; },
            { name = "c_sp5";
              id = 497871; 
              gff3 = 1; },
            { name = "b_xylophilus";
              id = 6326; 
              gff3 = 1; },
            { name = "c_drosophilae";
              id = 96641; },
            { name = "g_pallida";
              id = 36090; },
            { name = "h_bacteriophora";
              id = 37862; 
              gff3 = 1; },
            { name = "h_contortus";
              id = 6289;
              gff3 = 1;},
            { name = "m_hapla";
              id = 6305; 
              gff3 = 1;},
            { name = "m_incognita";
              id = 6306; 
              gff3 = 1;},
            { name = "n_brasiliensis";
              id = 36090; },
            { name = "o_volvulus";
              id = 6282; },
            { name = "s_ransomi";
              id = 554534; },
            { name = "s_ratti";
              id = 34506; 
              gff3 = 1;},
            { name = "t_circumcincta";
              id = 45464; },
            { name = "c_sp11";
              id = 886184; },
            { name = "t_muris";
              id = 70415; },
            { name = "t_spiralis";
              id = 6334; 
              gff3 = 1;},
            { nmae = "l_loa";
              id = 7209;
              gff3 = 1; }
); 



paper_types = (
  "journal_article", 
  "review", 
  "comment", 
  "news", 
  "letter", 
  "editorial", 
  "congresses", 
  "historical_article", 
  "biography", 
  "interview", 
  "lectures", 
  "interactive_tutorial", 
  "retracted_publication", 
  "technical_report", 
  "directory", 
  "monograph", 
  "published_erratum", 
  "meeting_abstract", 
  "gazette_article", 
  "book_chapter", 
  "book", 
  "email", 
  "wormBook", 
  "other"
);
END
    ;
    close OUT;
}


sub dump_pages_pseudo_ace_file {
    my ($self,$tmp_dir) = @_;
    $self->log->info("   --> dumping pages file");
    my $release = $self->release;
    open OUT,">$tmp_dir/Pages.ace";
    print OUT <<END;
Page : "/tools/blast_blat"
Public_name	"Blast/Blat"
Description	"Alignment tool"

Page : "/tools/comments"
Public_name	"Comments"
Description	"View comments left on WormBase"

Page : "/tools/genome/gbrowse/c_elegans"
Public_name	"GBrowse"
Description	"Browse the worm genome"

Page : "/tools/support"
Public_name	"Contact Help"
Description	"Send a message to the WormBase helpdesk"

Page : "/tools/nucleotide_aligner"
Public_name	"Nucleotide Aligner"
Description	"nucleotide aligner"

Page : "/tools/ontology_browser"
Public_name	"Ontologies"
Description	"Browse anatomy, gene and phenotype ontologies"

Page : "/tools/protein_aligner"
Public_name	"Protein Aligner"
Description	"protein aligner"

Page : "/tools/queries"
Public_name	"Queries"
Description	"Make ACe Query Language(AQL) and WormBase Query Language(WQL) queries directly"

Page : "http://www.textpresso.org/"
Public_name	"Textpresso"
Description	"Information extracting and processing (text mining) package for biological literature whose capabilities go far beyond that of a simple keyword search engine"

Page : "/tools/tree"
Public_name	"Tree Display"
Description	"View the raw data for this object or explore the underlying data model."

Page : "http://caprica.caltech.edu:9002/biomart/martview/"
Public_name	"WormMart"
Description	"Retrieve sequences and genome annotations using a variety of filters to constrain retrieved results"

Page : "http://www.wormbook.org/"
Public_name	"WormBook"
Description	"Provides an open-access collection of original, peer-reviewed chapters covering topics related to the biology of Caenorhabditis elegans (C. elegans)"

Page : "http://forums.wormbase.org"
Public_name	"Forum"
Description	"Worm Community Forum"

Page : "http://blog.wormbase.org"
Public_name	"Blog"
Description	"The Official WormBase Blog"

Page : "http://twitter.com/wormbase"
Public_name	"Twitter"
Description	"The Official WormBase Twitter Account"

Page : "http://github.com/WormBase"
Public_name	"Code Repositories (Github)"
Description	"WormBase Github code respoitories and issue tracker"

Page : "ftp://ftp.wormbase.org/pub/wormbase/"
Public_name	"FTP site"
Description	"Downloads - FTP site"
END
;
    close OUT;
}


1;
