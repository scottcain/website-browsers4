#!/usr/bin/perl

# Find new papers from one release of the database to another
# This requires that a list of WBPaper IDs be kept from the previous release

# Currently, I'm emailing this to Thomas and myself

use Ace;
use strict;
use lib '/usr/local/wormbase/cgi-perl/lib';
use ElegansSubs qw/ParseHash parse_year/;
use CGI qw/:standard/;
use Net::SMTP;
use MIME::Lite;

use constant OLD_PAPERS => '/usr/local/wormbase/html/papers/previous_papers.txt';
use constant NEW_PAPERS_HTML => '/usr/local/wormbase/html/papers/new_papers';

use constant PAPER_URL  => '/db/misc/paper?name=%s;class=Paper';
use constant DOI_URL    => 'http://dx.doi.org/';
use constant WBG        => 'http://elegans.swmed.edu/wli/';
use constant PUBMED_URL => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&cmd=retrieve&dopt=abstract&list_uids=';

my $path = shift;
$path or die "Usage: $0 [path/to/acedb/database]\n";
my $db = Ace->connect(-path => $path);


my %old = fetch_old_papers();

# New becomes old...
my $version = $db->status->{database}{version};
my $date    = `date +%Y-%m-%d`;
chomp $date;

open OLD,">" . OLD_PAPERS;
open HTML,">" . NEW_PAPERS_HTML . "_$version.html";


my @new = sort { parse_year($b) <=> parse_year($a) } grep { !$old{$_} } $db->fetch(Paper => '*');
my @purged;
foreach (@new) {
    next if $_->Type eq 'MEETING_ABSTRACT';  # Ignore meeting abstracts
	push @purged,$_;
}

print HTML start_html({-title=>"New papers added to WormBase: release $version"});
print HTML h2("New papers added to WormBase: release $version");
print HTML scalar @purged . " new papers were added to WormBase release $version<br><br>";
print HTML "# Generated: $date<br>";
print HTML "<ul>";

foreach (sort { $a->Author cmp $b->Author } @purged) {
    my $citation = build_citation($_);
    print HTML "<li>$citation\n";
    print OLD "$_\n";   # save the ID for future reference
}

print HTML "</ul>";
close HTML;
close OLD;

system("cd /usr/local/wormbase/html/papers; rm newest_papers.html; ln -s new_papers_$version.html newest_papers.html");

#send_email();
exit;



sub fetch_old_papers {
    open IN,OLD_PAPERS or die "Couldn't open the old papers text file";
    my %old;
    while (<IN>) {
	next if /^\#/;
	chomp;
	$old{$_}++;
    }
    close OLD_PAPERS;
    return %old;
}



sub build_citation {
    my $paper = shift;

    my @authors = $paper->Author;
    my $authors = @authors <= 2 ? (join ' and ',@authors) : "$authors[0] et al.";
    my @affil   = $paper->Affiliation;

    # The paper or chapter title
    my ($title)   = $paper->Title;
    $title =~ s/\.*$//;
    
    # The journal title
    my ($journal) = $paper->Journal;
    
    # the worm meetings don't have a journal
    $journal ||= 'Meeting abstract' if $paper->Meeting_abstract;
    
    # fix a bug in some data records    
    if ($paper->WBG_abstract) {
	$journal ||= "Worm Breeder's Gazette";
	my $target = CGI::escape ("[" . $paper->WBG_abstract . "]");
	$journal = a({ -href=>WBG . $target},$journal);
    }
    
    # Volume
    my ($volume)  = $paper->Volume;
    $volume = "$volume:" if $volume;
    
    # Pages
    my $pages  = join('-',$paper->Page->row) if $paper->Page;
    
    my @links;
    # WormBase
    push @links, a({-name=>$paper,-href=>sprintf(PAPER_URL,$paper)},"[WormBase]");
    
    # Link to PMID
    push @links,a({-href=>PUBMED_URL . $paper->PMID},"[PubMed]") if $paper->PMID;

    # Link to WormBook
    if ($paper->Type eq 'WormBook') {
	my $doi = $paper->Other_name;
	
	# Link to the chapter - Now just using "WormBook"
	push @links,a({-href=>DOI_URL . $doi},'[WormBook]');
    }


    my $citation;
    # Parse the Paper hash if this is a book citation
    my %parsed;
    if ($paper->In_book || $paper->Erratum) {
	my $data = ParseHash(-nodes=>$paper->In_book);
	# There should be only a single node...
	# Piggybacking on some pre-existing code
	
	foreach my $node (@{$data}) {
	    my $hash = $node->{hash};
	    foreach (qw/Title Editor Publisher Year/) {
		$parsed{$_} = $hash->{$_} =~ /ARRAY/ ? join(', ',@{$hash->{$_}}) : $hash->{$_};
	    }
	    last;
	}
    }
    
    my $year = parse_year($paper->Year) || $parsed{Year};
    
    if ($paper->In_book) {
	if ($paper->Type eq 'WormBook') {
	    my $doi = $paper->Other_name;
	    $citation .= qq{$authors.<br>$title<br>\n$year. In: $parsed{Editor}, eds. $parsed{Title}, <br>\ndoi/$doi, <a href="http://www.wormbook.org">http://www.wormbook.org</a>.};
	} else {
	    $citation .= "$authors.<br>$title<br>\n$year. In: $parsed{Editor}. $parsed{Title}$pages.";
	}
    } else {
	$citation .= "$authors.<br>$title<br>\n$year. $journal $volume$pages.\n"; 
    }
    
#    $citation .= br . join(', ',@affil) if @affil;
    $citation .= br . join(' ',@links)  if @links;
    
    return $citation;
}








sub send_email {
    
    open HTML,NEW_PAPERS_HTML . "_$version.html";
    my @contents = <HTML>;
    close HTML;
    
    my $subject   = "WormBase: new papers for $version";
    my $mime_msg = MIME::Lite->new(
				   From    => 'toddwharris@gmail.com',
				   To      => 'toddwharris@gmail.com,Thomas.Burglin@sh.se',
				   Subject => $subject,
				   Type    => 'text/html',
				   Path => NEW_PAPERS_HTML . "_$version.html",
				   );

    $mime_msg->attach(
		      Type    => 'text/html',
		      Path => NEW_PAPERS_HTML . "_$version.html",
		      Disposition => 'attachment');
    
#		      Path => NEW_PAPERS_HTML . "_$version.html");
#    $mime_msg->attach($part);
    
    $mime_msg->send() or die "couldn't send emai";
}


