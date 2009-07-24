#!/usr/bin/perl

use strict;
use Ace;
use DBI;
use Bio::DB::GFF;
use Getopt::Long;

use constant MYSQL_DB => 'gene_search';
use constant MYSQL    => 'mysql';
use constant DEBUG    => 0;

# Create a simple single-table relational schema to power the gene search
$ENV{TMP} = $ENV{TMP} || $ENV{TMPDIR} || $ENV{TEMP} || -d ('/usr/tmp') ? '/usr/tmp' : -d ('/tmp') ? '/tmp' : die;

my ($RELEASE,$ACEDB,$MYSQL_USER,$MYSQL_PASS);
GetOptions('release=s' => \$RELEASE,
	   'acedb=s'   => \$ACEDB,
	   'muser=s'   => \$MYSQL_USER,
	   'mpass=s'   => \$MYSQL_PASS);

my @tables = qw/ genes names2genes/;

my $host = 'localhost';
my $port = '2005';

my $db;
if ($ACEDB && !$RELEASE) {
  $db = Ace->connect(-path=>$ACEDB);
} else {
  $db = Ace->connect(-host=>'localhost',-port=>2005);
}

$RELEASE  ||= $db->status->{database}{version};
my $MYSQL_DB = MYSQL_DB . "_$RELEASE";

create_mysql_db();
my $dbh = initialize();

exit;


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
  foreach (values %$schema) {
    $dbh->do($_) || warn $dbh->errstr;
  }
  return $dbh;
}


sub schema {
  my $tables = {};
  push (@{$tables->{genes}},
	{  gene_id          =>  'int not null auto_increment' },
	{  gene             =>  'text'                        },
	{  gene_class       =>  'text'                        },
	{  merged_into      =>  'text'                        },
	{  status           =>  'text'                        },
	{  species          =>  'text'                        },
	{  version          =>  'text'                        },
	{  bestname         =>  'text'                        },
	{  other_name_for   =>  'text'                        },
	{  public_name      =>  'text'                        },
	{  molecular_name   =>  'text'                        },
	{  cgc_name         =>  'text'                        },
	{  concise_desc      =>  'text'                       },
	{  gene_class_desc   =>  'text'                       },
	{  kog_desc          =>  'text'                       },
	{  genetic_position =>  'text'                        },
	{  genomic_start    =>  'text'                        },
	{  genomic_stop     =>  'text'                        },
	{  chromosome       =>  'text'                        },
	{ 'primary key(gene_id)' => 1                         },
	{ 'INDEX(gene_class(6))'       => 1                   },
#	{ 'INDEX(concise_desc(6))'      => 1                  },
#	{ 'INDEX(concise_desc(6))'      => 1                  },
       );

  push (@{$tables->{names2genes}},
	{  name_id       =>  'int not null auto_increment'    },
	{  name          =>  'text'                           },
	{  gene_id       =>  'int not null'                   },
	{ 'primary key(name_id)'  => 1                        },
	{ 'INDEX(name(12))'       => 1                        },
       );
  
  my %schema;
  foreach my $table (keys %$tables) {
    my $create = "create table $table (";
    my $count;
    foreach my $param (@{$tables->{$table}}) {
      $count++;
      # Append a comma to the previous entry, but only if this
      # isn't the first...
      $create .= ',' if ($count > 1);
      
      my ($key) = keys %$param;
      my ($val) = values %$param;
      if ($val == 1) {
	$create .= $key;
      } else {
	$create .= $key . ' ' . $val;
	# $create .= $key . ' ' . $val . ',';
      }
    }
    $create .= ')';
    $schema{$table} = $create;
  }
  return (\%schema,$tables);
}
