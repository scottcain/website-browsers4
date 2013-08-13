package WormBase::Update::Staging::MirrorWikiPathwaysImages;

use Moose;
use LWP::Simple;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'mirror images from wikipathways for use on process pages',
);

has 'wikipathways_base' => (
    is => 'ro',
    default => 'http://www.wikipathways.org//wpi/wpi.php?action=downloadFile&type=png&pwTitle=Pathway:',
    );

has 'output_directory' => (
    is => 'ro',
    default => '/usr/local/wormbase/website-shared-files/html/img-static/wikipathways',
    );


sub run {
    my $self    = shift;       
    my $release = $self->release;    
    my $acedb_path = join("/",$self->acedb_root,"wormbase_$release");
    
    my $db = Ace->connect(-path => $acedb_path) or $self->log->logdie("Could not connect to acedb at $acedb_path");
    
    my $url_base = $self->wikipathways_base;

    my @objs  = $db->fetch(WBProcess => '*');
    
    # Clear all previously downloaded images
    my $output_directory = $self->output_directory;
    chdir $output_directory or $self->log->logdie("Cannot navigate to $output_directory: $!");
    unlink glob '*.png';

    foreach my $obj (@objs) {
	
	# What pathways does this process contain?
	if ($obj->Pathway){
	    my $pathway = $obj->Pathway->right(3);
	    
	    my @rr = $pathway->col;
	    #print join(',',@rr),"\n";
	    
	    foreach my $wpid (@rr) {
		my $dl_url = $url_base . $wpid;
		my $dest_file = $wpid . '.png';
		getstore($dl_url,$dest_file);
	    }
	}	
    }
    $self->log->info("mirroring wikipathways images complete");
}


    
1;
