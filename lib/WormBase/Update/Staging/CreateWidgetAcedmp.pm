package WormBase::Update::Staging::CreateWidgetAcedmp;
use Moose;
use lib "/usr/local/wormbase/website/tharris/extlib";
use DBI;
extends qw/WormBase::Update/;

has 'step' => (
    is => 'ro',
    default => 'create Widgets.ace from mysql',
);
 
has 'widgets_ace_file' => (
    is => 'ro',
    lazy_build => 1
);

sub _build_widgets_ace_file {
    my $self = shift;
    return join("/", $self->acedmp_dir, "Widgets.ace");
}

sub run {
    my $self = shift;
    $self->log->info("generating Widgets.ace file for xapian");
    $self->create_ace_file();  # create Widgets.ace 
}

sub create_ace_file {
  my $self = shift;

  my $db = $self->wormbase_user_db;
  my $user = $self->wormbase_user_username;
  my $host=$self->wormbase_user_host;

  my $widgets_ace_file = $self->widgets_ace_file;

  open OUT, "> $widgets_ace_file" or die "Cannot open $widgets_ace_file";
  
  ## SQL query
  my $query = 
  "SELECT p.url, 
          p.title, 
          w.widget_title,
          u.username,
          u.wbid,
          w.widget_order,
          wr.content
    FROM widgets w, 
          widget_revision wr, 
          pages p,
          users u
    WHERE w.widget_id = wr.widget_id 
      AND w.current_revision_id = wr.widget_revision_id 
      AND w.page_id = p.page_id
      AND wr.user_id = u.user_id;
  ";
  
  my $dbh = DBI->connect("DBI:mysql:$db:$host", $user);
  my $sqlQuery  = $dbh->prepare($query)
  or die "Can't prepare $query: $dbh->errstr\n";
  
  my $rv = $sqlQuery->execute
  or die "can't execute the query: $sqlQuery->errstr";
  
  while (my @row= $sqlQuery->fetchrow_array()) {
    my $content = $row[6];
    $content =~ s/\n|\t|\s{2,}|\"/ /g;
    print OUT "Page : \"$row[0]\"\n";
    print OUT "Public_name\t\"$row[1]\"\n";
    print OUT "Widget_title\t\"$row[2]\"\n";
    print OUT "Editor\t\"$row[3]\"\n";
    print OUT "WBID\t\"$row[4]\"\n" if $row[4];
    print OUT "Widget_order\t\"$row[5]\"\n";
    print OUT "Content\t\"$content\"\n\n";
  }
  
  my $rc = $sqlQuery->finish;


  $query = 
  "SELECT p.url, 
          p.title, 
          u.username,
          u.wbid,
          c.content
    FROM comments c, 
          pages p,
          users u
    WHERE c.page_id = p.page_id
      AND c.user_id = u.user_id;
  ";
  
  $sqlQuery  = $dbh->prepare($query)
  or die "Can't prepare $query: $dbh->errstr\n";
  
  $rv = $sqlQuery->execute
  or die "can't execute the query: $sqlQuery->errstr";
  
  while (my @row= $sqlQuery->fetchrow_array()) {
    my $content = $row[4];
    $content =~ s/\n|\t|\s{2,}|\"/ /g;
    print OUT "Page : \"$row[0]\"\n";
    print OUT "Public_name\t\"$row[1]\"\n";
    print OUT "Type\t\"Comment\"\n";
    print OUT "Editor\t\"$row[2]\"\n";
    print OUT "WBID\t\"$row[3]\"\n";
    print OUT "Content\t\"$content\"\n\n";
  }
  
  $rc = $sqlQuery->finish;
  exit(0);
  close(OUT);
}

no Moose;
__PACKAGE__->meta->make_immutable;
