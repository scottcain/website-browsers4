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


# Seriously annoying legacy flat files.
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

has 'gene_id2omim_ids_txt_file' => (
    is         => 'ro',
    lazy_build => 1
    );

sub _build_gene_id2omim_ids_txt_file {
    my $self    = shift;
    return $self->datadir . "/gene_id2omim_ids.txt";
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
#     return "/usr/local/wormbase/tmp/acedmp/Disease.ace";
    return join("/", $self->acedmp_dir, "Disease.ace");
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
    
    # No longer required post-WS236
#    $self->create_disease_file($hash,$mm_hash);  # create Disease.ace 
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
    system("cp /usr/local/wormbase/website/production/util/omim/morbidmap.txt $filename");
    open MORBIDMAP, "< $filename" or $self->log->logdie("Cannot open $filename");

    foreach my $line (<MORBIDMAP>){
	my ($disorder,$gene,$omim,$location) = split /\|/,$line;
	$hash{$omim} = $gene if($omim && $gene);
    }
    close(MORBIDMAP);
    return \%hash;
}


sub copy_files_from_repository {
    my $self = shift;
    my $omim_descriptions = $self->omim_id2disease_desc_txt_file;
    system("cp /usr/local/wormbase/website/production/util/omim/omim_id2disease_desc.txt $omim_descriptions") or die "Couldn't copy omim desc file";

    my $omim_names = $self->omim_id2disease_name_txt_file;
    system("cp /usr/local/wormbase/website/production/util/omim/omim_id2disease_name.txt $omim_names") or die "Couldn't copy omim names file";

    my $gene_ids = $self->gene_id2omim_ids_txt_file;
    system("cp /usr/local/wormbase/website/production/util/omim/gene_id2omim_ids.txt $gene_ids") or die "Couldn't copy gene ids file";
}


# WS236: this is no longer necessary
sub create_disease_file{
    my ($self,$hash,$mm_hash)    = @_;

    my $omim_txt_file = $self->omim_txt_file;
    my $disease_ace_file = $self->disease_ace_file;
    
    my $filename = $self->omim_txt_file;    
    system("cp /usr/local/wormbase/website/production/util/omim/omim.txt.gz $filename.gz");
    system("gunzip $filename.gz");

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
