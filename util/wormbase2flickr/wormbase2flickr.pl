#!/usr/bin/perl

# Modify expression page.
#   Display official Wormbase images for a given expression pattern.
#   1.  From the WormBase flickr user.
#   2.  Be tagged with the expression pattern ID
# 
#   Display images from other users.
#   1. They must create flickr account
#   2. They must join the WormBase group
#   3. Images must be posted to the group AND tagged with the WBGeneID.

# Sets and collections:
#   Sets and collections could be exploited for greater organization.
#   For example, we could have a set for every gene containing all of its expression patterns.
#   This might just be additional and unnecessaryt overhead
#
#   Create flickr groups
#   Write documnetation on how to contribute
#   Write blog post: A distributed expression pattern archive for a model organism database

# Possible other tags:
#   AO terms


use strict;
use Flickr::API;
use Flickr::Upload;
use lib '.';
use WormBase2Flickr;
use Data::Dumper;
use Term::ProgressBar;
#		Term::ProgressBar->import(2.00);
use CGI qw/:standard/;
use Ace;
use FindBin qw/$Bin/;

use constant DEBUG       => 0;

my $show_progress = shift;
my $version = '0.01';
my %tickets;

# All images will have these base tags
my @base_tags = (
		 "Caenorhabditis elegans",
		 "expression pattern",		 
		 qw/nematode
		    genomics
		    www.wormbase.org
		    WormBase
		    new_group
		   /);


my $wb2flickr = WormBase2Flickr->new();
$wb2flickr->flickr_connection_test('wormbase') if DEBUG;

# Check which images have already been uploaded
my ($finished) = already_uploaded();

# Open some files
open ACE,">>out/pic2flickrid.ace";
open TXT,">>out/pic2flickrid.txt";
open ERR,">out/errors.txt";

# We also need a Flickr::Upload api object
my $api = Flickr::Upload->new({key    => $wb2flickr->api_key,
			       secret => $wb2flickr->app_secret,
			      });
$api->agent( "WormBaseUploader/$version" );


process_images();


# Check on the progress of uploads
print "Waiting for upload results (ctrl-C if you don't care)...\n";
do {
  sleep 1;
  my @checked = $api->check_upload( keys %tickets );
  for( @checked ) {
    if( $_->{complete} == 0 ) {
      # not done yet, don't do anythig
    } elsif( $_->{complete} == 1 ) {
      # uploaded, got photoid
      print "$tickets{$_->{id}} is at " .
	"http://www.flickr.com/tools/uploader_edit.gne?ids=$_->{photoid}\n";
      delete $tickets{$_->{id}};
    } else {
      print "$tickets{$_->{id}} failed to get photoid\n";
      delete $tickets{$_->{id}};
    }
  }
} while( %tickets );

exit 0;


sub process_images {
  my $db = Ace->connect(-host => 'aceserver.cshl.org',
			-port => 2005 )
    or die "Couldn't connect to Ace: $!";
  
  # Fetch all Expression pattern objects with associated images
  my @patterns = $db->fetch(-query => qq/find Expr_pattern where Picture/);
  
  foreach my $pattern (@patterns) {    
    foreach my $picture ($pattern->Picture) {
      if (defined $finished->{$picture}) {
	print STDERR "Already uploaded $picture\n";
	next;
      }
      
      my @tags = @base_tags;
      
      # Fetch salient information for each pattern.
      # We will use this to create appropriate titles, tags, and descriptions,
      # and to place the photo into sets and collections.
      
      # Hierarchy / Formatting
      # Title: [ Sequence || Sequence (locus) ]: .  [ Transgene || Type ]
      # Tags:
      #     generic: "Caenorhabditis elegans" nematode "expression pattern"
      #               WormBase www.wormbase.org genomics
      #     dynamic:  transgene ID, sequence ID, locus name, public gene name, WBGene ID
      #               subcellular localization, reporter gene type
      #               consider: AO?
      # Description:
      # WormBase Expression Pattern: [expression_pattern_ID (linked to WB)].
      # Filename: [picture filename]
      # Expression of: [locus ? sequence (locus) : sequence]
      # Transgene: [transgene (linked to WB)
      # Expressed in: [ao terms - not currently linked]
      # Subcellular localization: [subcellular localization]
      # Reporter_gene: [reporter gene]
      # In_site: [In Situ]
      # Antibody : [antibody]
      # Northern : [northern]
      # Western : [western]
      # RT_PCR :  [RT-PCR]
      # Localizome: [Localizome]
      # Laboratory: [lab (linked to WB; representative (linked to WB)]
      # Strain: [strain (linked to WB)]
      # Remark: [remark]
      # References: [Brief citations]
      
      # The title
      # Title: [ Sequence || Sequence (locus) ]: .  [ Transgene || Type ]
      # Locus_name (CDS): Transgene || CDS: Transgene
      my $gene     = $pattern->Gene;
      
      push @tags,$gene if $gene;
      my $sequence = $gene->Sequence_name if $gene;
      my $cds  = $pattern->CDS; 
      my $locus = $gene  ? $gene->CGC_name : undef;
      my $title =
	($locus ? "$sequence ($locus): " : "$sequence: ")      
	  . ( $pattern->Transgene ? $pattern->Transgene : $pattern->Type);
      
      my $public_name = $gene->Public_name if $gene;

      my @sections =
	b('WormBase Expression Pattern: ')
	  . a({-href=>$wb2flickr->wormbase_url . "/db/gene/expression?name=" . $pattern},$pattern);

      # Expression of:
      push @sections,
	b("Expression of: ")
	 . a({-href=>$wb2flickr->wormbase_url . "/db/gene/gene?name=$gene"},
	     ($locus ? "$sequence ($locus)" : $sequence)) if $gene;
      
      if ($pattern->Pattern) {
	push @sections,b("Pattern: ") . $pattern->Pattern;
      }
      
      # Localization:
      if (my $localization = $pattern->Subcellular_localization) {    
	push @sections,b("Subcellular localization: ") . $localization;
	push @tags,$localization;
      }
      
      # Anatomy_term.  Should probably be Term or something.
      if (my @ao = $pattern->Anatomy_term) {
	my @ao_entries = b("Associated Anatomy Ontology Terms");
	foreach my $ao_term ($pattern->Anatomy_term) {
	  push @ao_entries,a({-href=>$wb2flickr->wormbase_url . "/db/ontology/anatomy?name=$ao_term"},$ao_term->Term . " ($ao_term)");
	  push @tags,$ao_term;
	  push @tags,$ao_term->Term;
	}
	push @sections,join("\n",@ao_entries);
      }
      
      my @details = b("Experimental Details");      
      
      # Type
      my @type_tags = qw/Reporter_gene In_situ Antibody Northern Western RT_PCR Localizome/;
      my %types;
      foreach (@type_tags) {
	if (my $data = $pattern->$_) {
	  $_ =~ s/_/ /g;
	  $types{lc($_)} = $data;
	}
      }
      
      foreach (keys %types) {	
	push @details,b("Type: ") . $_ . " " . $types{$_};
	push @tags,$_;
	push @tags,$types{$_} if (length $types{$_}) <= 20;
      }
      
      push @details,b("Strain: ")
	. a({-href=>$wb2flickr->wormbase_url . "/db/misc/strain?name=" . $pattern->Strain},
	    $pattern->Strain)
	  if $pattern->Strain;
      
      if (my $transgene = $pattern->Transgene) {
	push @details, 
	  b("Transgene: ")
	    . a({-href=>$wb2flickr->wormbase_url . "/db/gene/transgene?name=" . $transgene},$transgene);
	
	push @details,b("Integration status: ") . ($transgene->Integrated_by eq 'Not_integrated' ? 'not integrated' : 'integrated');
	push @details,b("Clone details: ") . $transgene->Summary;
      }
      
      push @sections,join("\n",@details) if @details;
      
      # Save select descriptive items as dynamic tags:
      # Sequence name, locus, WBGeneID
      push @tags,$sequence;
      push @tags,$locus if $locus;
      push @tags,$pattern->Transgene if $pattern->Transgene;  
            
      # Origin details
      if ($pattern->Laboratory) {	

	my $laboratory = $pattern->Laboratory;
	my $rep = eval { $laboratory->Representative };
	
	push @sections,b("Origin:\n")
	  . b("Laboratory: ")
	    . a({-href=>$wb2flickr->wormbase_url . "/db/misc/laboratory?name=" . $laboratory}, $laboratory)
	      . ($rep ? 
		 a({-href=>$wb2flickr->wormbase_url . "/db/misc/person?name=" . $rep}, $rep->Full_name)
		 : '');
      }
      
      my $remark = join("; ",$pattern->Remark);
      push @sections, b("Remarks: ") . "$remark" if $remark;
      
      if ($pattern->Reference) {
	my @references = $pattern->Reference;
	my $c;
	if (@references) {
	  my @refs = b("References");
	  foreach (@references) {
	    $c++;
	    push @refs,"$c. "
	      . a({-href=>$wb2flickr->wormbase_url . "/db/misc/paper?name=$_"},$_->Brief_citation);
	  }
	  push @sections,join("\n",@refs);
	}
      }
      
      # Fetch the *current* name of the image
      # I'll map this to the filesystem below.
      push @sections, i("Original image: $picture");
      
      push @sections, i('NOTE: This image has been added to Flickr by <a href="http://www.wormbase.org/">WormBase</a> staff. Notice problems with the annotations?  Feel free to leave a comment here.  If you would like to add your <b>own</b> expression patterns for automatic display on WormBase, please see the <a href="http://flickr.com/groups/869508@N22/">WormBase Group</a> right here on Flickr!.');
      
      my $description .= join("\n\n",@sections);
#      my $description = join("<br>",@description);    
      my $tags = join(" ",map { qq{"$_"} } @tags);
#      print $description;
      upload_photo($pattern,$picture,$title,$tags,$description);

    }
  }
}

# Upload the photo to Flickr, saving the response.
# This will be the unique ID of the photo
sub upload_photo {
  my ($pattern,$filename,$title,$tags,$description) = @_;
  
  my $photo;
  if (-e "$Bin/expression_archive/localizome/$filename") {
    $photo = "./expression_archive/localizome/$filename";
  } elsif (-e "$Bin/expression_archive/assembled/$filename") {
    $photo = "./expression_archive/assembled/$filename";
  } elsif (-e "$Bin/expression_archive/patterns/$filename") {
    $photo = "./expression_archive/patterns/$filename";  
  } elsif (-e "$Bin/expression_archive/overlay/$filename") {
    $photo = "./expression_archive/overlay/$filename";
  }
  
  if (!$photo) {
    print ERR "Couldn't find the correct file for $filename...\n";
    warn "Couldn't find the correct file for $filename...\n";
    next;
  } else {
    print "Found the photo for $pattern: $photo\n" if $photo;
  }

  my %args = (
	      auth_token  => $wb2flickr->auth_token,
	      description => $description,
	      title       => $title,
	      tags        => $tags,
	      is_public   => 1,
	      is_friend   => 1,
	      is_family   => 1,
	     );

  my $photoid;
  if ($show_progress) {
    $args{async} = 1;
    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
    my $photo_size = (stat($photo))[7];
    my $req = $api->make_upload_request( 'photo' => $photo, %args );
    my $gen = $req->content();
    die unless ref($gen) eq "CODE";
    
    my $progress = Term::ProgressBar->new({
					   name => $photo,
					   count => $photo_size,
					   ETA => 'linear',
					  });
    $progress->minor(0);
    
    my $state;
    my $size;
    
    $req->content(
		  sub {
		    my $chunk = &$gen();
		    
		    $size += Flickr::Upload::file_length_in_encoded_chunk(\$chunk, \$state, $photo_size);
		    $progress->update($size);
		    
		    return $chunk;
		  }
		 );
    
    $photoid = $api->upload_request( $req );
  } else {
    
    print 'Uploading ', $photo, "...\n";
    $photoid = $api->upload (
			     photo => $photo,
			     %args
			    ) or print ERR "Failed to upload $photo\n";
  }
  
  # check those later
  $tickets{$photoid} = $photo;
  
  # Save the photo IDs as an ace file
  # I don't think it's actually necessary to do this.
  
  print TXT "$pattern\t$filename\t$photoid\n";
  
  foreach (keys %tickets) {
    print ACE <<END;
Expr_pattern : $pattern
Remark "FlickrID $_"
END
  }
}

sub already_uploaded {
  open TXT,"out/pic2flickrid.txt"; 
  my %finished;
  while (<TXT>) {

    my ($expr,$filename,$photoid);
    ($expr,$filename,$photoid) = $_ =~ /(.*)\t(.*)\s+?(.*)\n/;
    unless ($filename) {
      ($expr,$filename,$photoid) = split("\t");
    }
    $filename =~ s/\s//g;
    $finished{$filename}++;
  }
  close OUT;
  return \%finished;
}
