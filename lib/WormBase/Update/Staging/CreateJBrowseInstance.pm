package WormBase::Update::Staging::CreateJBrowseInstance;

use Moose;
extends qw/WormBase::Update/;
use Config::Tiny;
use File::Copy;
use Cwd;
use FileHandle;
use File::Basename;
use JSON;

# The symbolic name of this step
has 'step' => (
    is => 'ro',
    default => 'create jbrowse data sets',
    );

has 'jbrowse_destination' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_jbrowse_destination {
    my $self = shift;
    my $release = $self->release;
    my $path  = join("/","/usr/local/wormbase",'jbrowse_releases',$release);
    $self->_make_dir($path);
    return $path;
}

has 'jbrowse_workingdir' => (
    is => 'ro',
    );

sub _build_jbrowse_workingdir {
    my $self = shift;
    my $workingdir = $self->jbrowse_destination . "/build";
    $self->_make_dir($workingdir);
    return $workingdir;
}

has 'jbrowse_sourcecode' => (
    is => 'ro',
    );

has 'jbrowse_version' => (
    is => 'ro',
    default => 'JBrowse-1.11.6',
    );

sub _build_jbrowse_sourcecode {
    my $self = shift;
    my $version = $self->jbrowse_version . '.zip';
    my $source  = join("/", '/usr/local/wormbase/website/scain', $version);
    return $source;
}


has 'desired_species' => (
    is => 'ro',
    );

has 'desired_bioproject' => (
    is => 'ro',
    );
   
has 'confirm_only' => (
    is => 'ro',
    );

has 'filedir' => (
    is => 'ro',
    default => '/usr/local/ftp/pub/wormbase/releases/'
    );

has 'gfffile' => (
    is => 'rw',
    );

has 'tmpdir' => (
    is => 'rw',
    );

has 'includes' => (
    is => 'rw',
    );

sub run {
    my $self = shift;

    # get a list of (symbolic g_species) names
    my $desired_species = $self->desired_species;
    my $species = [];
    if ($desired_species) {
	push @$species,$desired_species;      
    } else {
	($species) = $self->wormbase_managed_species;
    }
 
    my $release = $self->release;

    $self->setup_jbrowse_dir();

    foreach my $name (sort { $a cmp $b } @$species) {

	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });

	$self->log->info(uc($name). ': start');	

	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	foreach my $bioproject (@$bioprojects) {

	    if ($self->confirm_only) {
		$self->confirm_contents($bioproject);
		next;
	    }


            my $id = $bioproject->bioproject_id;
            if ($self->desired_bioproject and $id ne $self->desired_bioproject) {
                $self->log->info(  "Skipping $id; it is not the requested bioproject");
                next;
            }

	    unless ($bioproject->has_been_updated) {
		$self->log->info(  "Skipping $name; it was not updated during this release cycle");
		next;
	    }

	    $self->log->info("   Processing bioproject: $id");

            $self->run_prepare_refseqs($bioproject);
            $self->run_flatfile_to_json_names($bioproject);
            $self->run_generate_names($bioproject);
            $self->run_flatfile_to_json_nonames($bioproject);
            $self->build_tracklist($bioproject);

	}
	$self->log->info(uc($name). ': done');
    }

    $self->log->info("Finalizing JBrowse install");
    $self->cleanup();
}

sub setup_jbrowse_dir {
    my $self = shift;

    $self->log->info("This hasn't been written yet--been doing it by hand so far");
    return;

    #get JBrowse tarball, unpack
    copy ($self->jbrowse_sourcecode, $self->jbrowse_destination);
    chdir $self->jbrowse_sourcecode or die "couldn't chdir to ".$self->jbrowse_sourcecode;
    $self->system_call("unzip ".$self->jbrowse_version.".zip", "unzipping ".$self->jbrowse_version );
    $self->system_call("mv ".$self->jbrowse_version." jbrowse", "renaming ".$self->jbrowse_version. " to jbrowse");
    chdir 'jbrowse' or die "couldn't chdir into jbrowse directory";

    #run ./setup.sh
    $self->system_call('./setup.sh', 'running ./setup.sh for JBrowse');
    die;

    #make symlinks that will be needed
}

sub run_prepare_refseqs {
    my ($self,$bioproject) = @_;

    #fetch fasta and gff files
    my $datapath   = $self->filedir . $self->release . "/species/" . $bioproject ;
    my $fastafile  = "$bioproject.".'.'.$self->release.'.genomic.fa';

    my $tmpdir = $self->tmp_dir;

    my $copyfailed = 0;
    copy("$datapath/$fastafile.gz", $tmpdir) or $copyfailed = 1;

    if ($copyfailed) {
        #used to have tool here to get the file from ft.wormbase.org, probably don't need that anymore
        die "copying fasta file for $bioproject failed";
    }

    $self->system_call("gunzip -f $tmpdir/$fastafile.gz", "unziping $tmpdir/$fastafile");
    (-e $tmpdir/$fastafile) or die "No fasta file: $tmpdir/$fastafile";

    my $command = "nice bin/prepare-refseqs.pl --fasta $tmpdir/$fastafile --out ".$self->jbrowse_destination;
    $self->system_call($command, "running prepare-refseqs for $bioproject");

    return;
}

sub run_flatfile_to_json_names {
    my ($self,$bioproject) = @_;
}

sub run_generate_names {
    my ($self,$bioproject) = @_;
}

sub run_flatfile_to_json_nonames {
    my ($self,$bioproject) = @_;
}

sub build_tracklist {
    my ($self,$bioproject) = @_;
}

sub cleanup {
    my $self = shift;

    #make the "c_elegans_simple" dataset
    #make any remaining symlinks that are required
}


1;

