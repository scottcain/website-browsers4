#!/usr/bin/perl

use strict;
use Ace;
use DBI;
use Bio::DB::GFF;
use Getopt::Long;

use constant MYSQL_DB => 'gene_search';
use constant MYSQL    => 'mysql';
use constant DEBUG    => 0;
use constant NULL     => '\N';

# Create a simple single-table relational schema to power the gene search
$ENV{TMP} = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : die;

my ($RELEASE,$ACEDB,$MYSQL_USER,$MYSQL_PASS);
GetOptions(
	   'acedb=s'   => \$ACEDB,
	   'muser=s'   => \$MYSQL_USER,
	   'mpass=s'   => \$MYSQL_PASS);


die "Usage: gene_search.pl --muser --mpass" unless $MYSQL_PASS && $MYSQL_USER;

my $host = 'localhost';
my $port = '2005';

my $db;
if ($ACEDB) {
  $db = Ace->connect(-path=>$ACEDB);
} else {
  $db = Ace->connect(-host=>'localhost',-port=>2005);
}

my $cegff = Bio::DB::GFF->new( -adaptor => 'dbi::mysqlopt',
			       -dsn     => 'dbi:mysql:elegans',
#			       -dsn     => 'dbi:mysql:elegans:aceserver.cshl.org',
			       -user    => 'root',
			       -pass    => 'kentwashere');
my $cbgff = Bio::DB::GFF->new( -adaptor => 'dbi::mysqlopt',
#			       -dsn     => 'dbi:mysql:briggsae:aceserver.cshl.org',
			       -dsn     => 'dbi:mysql:briggsae',
			       -user    => 'root',
			       -pass    => 'kentwashere');

$RELEASE  ||= $db->status->{database}{version};
my $MYSQL_DB = MYSQL_DB . "_$RELEASE";

my @tables = qw/genes names2genes/;
my %names2genes;
my $genes = {};

# The names2genes table
open NAMES2GENES,">$ENV{TMP}/names2genes-$RELEASE" or die "Couldn't open temporary file: $!";


create_mysql_db();
my $dbh = initialize();

dump_genes();
#dump_sequences();   # Unnecessary?
#dump_variations();  # Unnecessary?  Should have touched all variations in dump_genes
#dump_homol();       # Unnecessary?  Should already be handled

dump_tables($dbh);
load($dbh);
chdir('/usr/local/mysql/data');
unlink("gene_search");
system("ln -s gene_search_$RELEASE gene_search");
exit;


#sub stuff_gene_class {
#  my $gene_class    = shift;
#  my $id = $gene_classes->{$gene_class}->{id} = $id;
#  $id  ||= (scalar keys %{$gene_classes});
#  return $id;
#}

sub dump_genes {
  print STDERR "Dumping genes...\n";
  my $iterator = $db->fetch_many(-class => 'Gene',-name => '*');
  my $total    = $db->count('Gene' => '*');

  my $c;
  while (my $gene = $iterator->next) {
    $c++;
    last if $c == 100 && DEBUG;
    display_count($c,"Dumping gene $gene: $c of $total...");

    # Descriptions
    my $gc_desc = eval {$gene->Gene_class->Description} || NULL;
    
    # All of the names will go in the names2genes table
    # Add coordinates
    my ($chrom,$start,$stop,$gmap,$gmap_chrom);
    ($chrom,$start,$stop) = get_genomic_position($gene);
    ($gmap_chrom,$gmap)   = get_genetic_position($gene);

    # Maybe a non-canonical gene, should probably be a gene ID
    my $other_name = eval { $gene->Public_name->Other_name_for };

    my $molecular_names = join('; ',$gene->Molecular_name);
    my $other_names     = join('; ',$gene->Other_name);
    my $species         = $gene->Species;
    my $version         = $gene->Version;
    my $merged          = $gene->Merged_into;
    my $status          = get_status($gene);
    my $gene_class      = $gene->Gene_class;
    my $bestname        = bestname($gene);
    my $cgc_name        = $gene->CGC_name;
    my $public_name     = $gene->Public_name;
    my $sequence_name   = $gene->Sequence_name;
    my $description     = $gene->Concise_description;
    
    # Create a concatenated string of gene ontology terms
    my @go = $gene->GO_term;
    my $go = join('; ',map { $_ .':' . $_->Term . "--" . $_->Definition } @go);

    $genes->{$gene} = { gene_id        => $c,
			gene           => $gene,
			gene_class     => $gene_class,
			status         => $status,
			merged_into    => $merged,
			species        => $species,
			version        => $version,
			other_name     => $other_names         || NULL,
			bestname       => $bestname            || NULL,
			cgc_name       => $cgc_name            || NULL,
			public_name    => $public_name         || NULL,
			molecular_name => $molecular_names     || NULL,
			sequence_name  => $sequence_name       || NULL,
			concise_description    => $description || NULL,
			gene_class_description => $gc_desc,
			genetic_position => $gmap,
			genomic_start    => $start,
			genomic_stop     => $stop,
			chromosome       => $chrom || $gmap_chrom,
			go               => $go,
		      };

    # Create an exceedingly simple name2gene join table so that users can search by 
    # gene, sequence, ests, variations, etc
    my @names;
    
    # Get all associated proteins
    my @proteins;
    foreach ($gene->Corresponding_CDS) {
      push @proteins,$_->Corresponding_protein;
    }
    
    # Homology groups
    foreach (@proteins) {
      my @homol = $_->Homology_group;
      foreach my $homol (@homol) {
	my $data = $homol . ($homol->Title ? ':' . $homol->Title : '');
	push @{$genes->{$gene}->{homol_description}},$data;
      }
      push @names,@homol;
    }
    
    #    my @names;
    #    push @names,$gene;
    #    push @names,$gene->Public_name;
    #    push @names,$gene->Sequence_name;
    #    push @names,$gene->Molecular_name;
    #    push @names,$gene->CGC_name;
    #    push @names,$gene->Other_name;
    #    push @names,$gene->Corresponding_CDS;
    #    push @names,$gene->Corresponding_transcript;
    #    push @names,$gene->Corresponding_pseudogene;
    #    push @names,@proteins;
    #    push @names,@go;
    
    push @names,$gene,
      $gene->Public_name,
	$gene->Sequence_name,
	  $gene->Molecular_name,
	    $gene->CGC_name,
	      $gene->Other_name,
		$gene->Corresponding_CDS,
		  $gene->Corresponding_transcript,
		    $gene->Corresponding_pseudogene,
		      $gene->Allele,
			@proteins,
			  @go;

    foreach (@names) {
      # push @{$names2genes{$_}},$gene_id;
      dump2names($_,$c);
    }
  }
}

sub dump_sequences {
  print STDERR "Dumping sequences...\n";
  my $c = 0;
  # Handle other sequences like ESTs, too
  my $iterator = $db->fetch_many('Sequence' => '*');
  my $total    = $db->count('Sequence' => '*');
  while (my $sequence = $iterator->next) {

    $c++;
    last if $c == 100 && DEBUG;
    display_count($c,"Dumping sequence $sequence: $c of $total...");
    # next if (defined $names2genes{$sequence});

    # All of these names SHOULD be unique
    my @genes = $sequence->Gene;
    unless (@genes) {
      my @cds = $sequence->Matching_CDS;
      @genes = map {$_->Gene } @cds if @cds;
    }

    next unless @genes;
    foreach my $gene (@genes) {
      my $gene_id = $genes->{$gene}->{gene_id};

      # THIS SHOULD NEVER HAPPEN AS WE HAVE ALREADY ITERATED THROUGH ALL GENES
      $gene_id  ||= (scalar keys %$genes) + 1;
      # push @{$names2genes{$sequence}},$gene_id;
      dump2names($sequence,$gene_id);
    }
  }
}

sub dump_variations {
  print STDERR "Dumping variations...\n";
  my $c = 0;
  my $iterator = $db->fetch_many('Variation' => '*');
  my $total    = $db->count('Variation' => '*');
  while (my $variation = $iterator->next) {
    $c++;
    last if $c == 100 && DEBUG;
    display_count($c,"Dumping variation $variation: $c of $total...");

    # next if (defined $names2genes{$variation});
    my @genes = $variation->Gene;
    foreach my $gene (@genes) {
      my $gene_id = $genes->{$gene}->{gene_id};
      # THIS SHOULD NEVER HAPPEN AS WE HAVE ALREADY ITERATED THROUGH ALL GENES
      $gene_id  ||= (scalar keys %$genes) + 1;
      #push @{$names2genes{$variation}},$gene_id;
      dump2names($variation,$gene_id);
    }
  }
}

sub dump_homol {
  print STDERR "Dumping kogs...\n";
  my $iterator = $db->fetch_many('Homology_group' => '*');
  my $total    = $db->count('Homology_group' => '*');
  my $c = 0;
  while (my $homol = $iterator->next) {
    $c++;
    last if $c == 100 && DEBUG;
    display_count($c,"Dumping homol $homol: $c of $total...");

    my @proteins = $homol->Protein;
    next unless @proteins;
    my @cds = map { $_->Corresponding_CDS } @proteins;
    next unless @cds;
    my @genes = map { $_->Gene } @cds;
    my $data = $homol . ($homol->Title ? ':' . $homol->Title : '');
    foreach my $gene (@genes) {
      push @{$genes->{$gene}->{homol_description}},$data;

      # Make genes searchable by KOG ID also (CAN BE A MANY TO MANY)!
      my $id = $genes->{$gene}->{gene_id};
      dump2names($homol,$id);
    }
  }
}

sub get_status {
  my $gene = shift;
  if (my $obj = eval {$gene->Corresponding_CDS->Corresponding_protein} ) {
    unless ($obj->Wormpep(0) || $obj->Database eq 'WormPep' || $obj =~ /^BP/)
      { # foreign protein from somewhere
	return 'foreign';
      }
    return 'live';
  } elsif ($gene->Merged_into) {
    return 'merged';
  } else {
    return 'live';
  }
}


sub display_count {
  my ($count,$msg) = @_;
  if ($count % 10 == 0) {
    print STDERR $msg;
    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
  }
}


sub bestname {
  my $gene = shift;
  my $name = $gene->Public_name || $gene->CGC_name || $gene->Sequence_name;
  die "No bestname for $gene...\n" if !$name;
  #|| eval { $gene->Corresponding_CDS->Corresponding_protein } || $gene;
  return $name;
}


sub dump_tables {
  my $tmp = $ENV{TMP};
  # The Gene table
  open OUT,">$tmp/genes-$RELEASE" or die "Couldn't open temporary file: $!";
  my @fields = qw/gene_id
		  gene
		  gene_class
		  merged_into
		  status
		  species
		  version
		  bestname
		  other_name
		  public_name
		  molecular_name
		  sequence_name
		  cgc_name
		  concise_description
		  gene_class_description
		  homol_description
		  genetic_position
		  genomic_start
		  genomic_stop
		  chromosome
		  go/;
  foreach my $gene (sort { $genes->{$a}->{gene_id} <=> $genes->{$b}->{gene_id} } keys %$genes) {
    my @cells;
    foreach (@fields) {
      my $val;
#      if (ref $genes->{$gene}->{$_} =~ /array/i) {
      if ($_ eq 'homol_description') {
	$val = join('; ',eval { @{$genes->{$gene}->{$_}} });
      } else {
	$val = $genes->{$gene}->{$_};
      }
      $val = ($_ eq 'gene_id') ? NULL : $val;
      push @cells,$val;
    }
    print OUT join("\t",@cells),"\n";
  }
  close OUT;
  
  #  # The names2genes table
  #  open OUT,">$tmp/names2genes-$RELEASE" or die "Couldn't open temporary file: $!";
  #  my $c;
  #  foreach my $name (keys %names2genes) {
  ##    print OUT join("\t",++$c,$name,$names2genes{$name}),"\n";
  #    print OUT join("\t",$name,$names2genes{$name}),"\n";
  #  }
  #  close OUT;
}


# Dump to the names table on the fly
sub dump2names {
  my ($name,$gene_id) = @_;
  print NAMES2GENES "$name\t$gene_id\n";
}
#  my $c;
#  foreach my $name (keys %names2genes) {
##    print OUT join("\t",++$c,$name,$names2genes{$name}),"\n";
#    print OUT join("\t",$name,$names2genes{$name}),"\n";
#  }
#  close OUT;
#}


sub load {
  my $dbh = shift;
  print STDERR "Loading tables...\n";
  my $tmp = $ENV{TMP};
  foreach (@tables) {
    if (-e "$tmp/$_" . "-$RELEASE") {
      print STDERR "loading table $_...\n";
      $dbh->do("load data infile '$tmp/$_-$RELEASE' replace into table $_") or warn "COULDN'T LOAD TABLE $_";
    }
#    unlink "$tmp/$_";
  }
}


sub create_mysql_db {
  my $success = 1;
  my $command =<<END;
${\MYSQL} -u $MYSQL_USER -p$MYSQL_PASS -h $host -e "create database $MYSQL_DB"
END
  ;
  $success && system($command) == 0;
  die "Couldn't create the database $db" if !$success;
}


sub initialize {
  my ($erase) = shift;

  my $dbh;
  if ($MYSQL_PASS && $MYSQL_USER) {
    $dbh = DBI->connect("dbi:mysql:$MYSQL_DB" . ';host=' . $host,$MYSQL_USER,$MYSQL_PASS)
  } elsif ($MYSQL_USER) {
    $dbh = DBI->connect("dbi:mysql:$MYSQL_DB" . ';host=' . $host,$MYSQL_USER);
  } else {
    $dbh = DBI->connect("dbi:mysql:$MYSQL_DB" . ';host=' . $host);
  }

  local $dbh->{PrintError} = 0;
  foreach (@tables) {
    $dbh->do("drop table $_");
  }
  
  my ($schema,$raw_schema) = schema();
  foreach my $table (keys %$schema) {
    my $command = $schema->{$table}->{table};
    $dbh->do($command) || warn $dbh->errstr;
  }
  return $dbh;
}


sub schema {
  my %schema = (
		genes => {
			  table=> q{
create table genes (
     gene_id                   int not null auto_increment,
     gene                      varchar(14),
     gene_class                varchar(6),
     merged_into               varchar(14),
     status                    varchar(5),
     species                   varchar(30),
     version                   tinyint,
     bestname                  varchar(15),
     other_name                varchar(100),
     public_name               varchar(15),
     molecular_name            varchar(100),
     sequence_name             varchar(15),
     cgc_name                  varchar(10),
     concise_description       text,
     gene_class_description    text,
     homol_description         text,
     genetic_position          float,
     genomic_start             int,
     genomic_stop              int,
     chromosome                varchar(5),
     go                        text,
     primary key(gene_id),
     index(gene(10)),
     index(gene_class(4)),
     index(genetic_position),
     index(genomic_start),
     index(genomic_stop),
     index(chromosome(5)),
     fulltext(concise_description),
     fulltext(homol_description),
     fulltext(gene_class_description),
     fulltext(go),
     fulltext(concise_description,homol_description,gene_class_description,go)
) type=MyISAM
}
},

		names2genes => {
table => q{
create table names2genes (
     name       varchar(20),
     gene_id    int not null
 ) type=MyISAM
}
},
);

return \%schema;
}


sub get_genetic_position {
  my $gene = shift;
  my ($chrom,undef,$position,undef,$error) = eval{$gene->Map(1)->row};
  if ($chrom && $position) {
    return ($chrom,$position);
  } else {
    my ($chrom,$pos) = GetInterpolatedPosition($db,$gene);
    return ($chrom,$pos) if ($chrom && $pos);

    for my $cds ($gene->Corresponding_CDS) {
      my ($chrom,$pos) = GetInterpolatedPosition($db,$cds);
      return ($chrom,$pos) if ($chrom && $pos);
    }
  }
}

sub GetInterpolatedPosition {
  my ($db,$obj) = @_;
  my ($full_name,$chromosome,$position);
  if ($obj->class eq 'CDS') {
    # Is it a query
    # wquery/genelist.def:Tag Locus_genomic_seq
    # wquery/new_wormpep.def:Tag Locus_genomic_seq
    # wquery/wormpep.table.def:Tag Locus_genomic_seq
    # wquery/wormpepCE_DNA_Locus_OtherName.def:Tag Locus_genomic_seq
    
    # Fetch the interpolated map position if it exists...
    # if (my $m = $obj->get('Interpolated_map_position')) {
    if (my $m = eval {$obj->get('Interpolated_map_position') }) {
      #my ($chromosome,$position,$error) = $obj->Interpolated_map_position(1)->row;
      ($chromosome,$position) = $m->right->row;
      return ($chromosome,$position) if $chromosome;
    } elsif (my $l = $obj->Gene) {
      return GetInterpolatedPosition($db,$l);
    }
  } elsif ($obj->class eq 'Sequence') {
    #my ($chromosome,$position,$error) = $obj->Interpolated_map_position(1)->row;
    my $chromosome = $obj->get(Interpolated_map_position=>1);
    my $position   = $obj->get(Interpolated_map_position=>2);
    return ($chromosome,$position) if $chromosome;
  } else {
    $chromosome = $obj->get(Map=>1);
    $position   = $obj->get(Map=>3);
    return ($chromosome,$position) if $chromosome;
    if (my $m = $obj->get('Interpolated_map_position')) {
      my ($chromosome,$position,$error) = $obj->Interpolated_map_position(1)->row;
      ($chromosome,$position) = $m->right->row unless $position;
      return ($chromosome,$position) if $chromosome;
    }
  }
  return;
}

sub get_genomic_position {
  my $gene = shift;
  my @segments = segments($gene);
  return ('',NULL,NULL) unless @segments;

  my $longest = longest_segment(\@segments);
  my ($r,$s,$e) = ($longest->abs_ref,$longest->abs_start,$longest->abs_end);
  return ($r,$s,$e);
}


# Find the longest GFF segment
sub longest_segment {
  my $segs = shift;
  my @sorted = sort { ($b->abs_end-$b->abs_start) <=> $a->abs_end-$a->abs_start } @$segs;
  return $sorted[0];
}


sub segments {
  my $gene = shift;

  if ($gene->Species =~ /briggsae/) {
    my $db = $cbgff;
    my @sequences = $gene->Corresponding_CDS,$gene->Corresponding_transcript;
    my @tmp = map {$db->segment(CDS => "$_")} @sequences;
    @tmp = map {$db->segment(Pseudogene => "$_")} @sequences unless (@tmp);
    return @tmp;
  }

  my @segments = $cegff->segment(Gene => $gene);
  return @segments;
}
