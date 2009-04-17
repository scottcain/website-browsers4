package Update::LoadAutocompleteDB;

use strict;
use base 'Update';
use DBI;
use FindBin '$Bin';
use File::Basename 'basename';
use lib '/usr/local/wormbase/cgi-perl/lib';
use WormBase::Autocomplete;

# The symbolic name of this step
sub step { return 'build the autocomplete database'; }

sub run {
  my $self = shift;
  my $release = $self->release;
  $self->target_db("autocomplete_$release");
  $self->create_db();
  
  my $acedb = $self->acedb_root . '/elegans' . "_$release";
  
  # Move into the scripts dir and get all autocomplete loaders
  chdir("$Bin/../util/autocomplete");
  my @loaders = grep { ! /~$/ } glob("load*");
  foreach my $loader (@loaders) {
      $self->logit->debug("Running $loader $release $acedb");
      my $cmd = "$loader $release $acedb";
      system($cmd);
  }


  $self->update_symlink({path    => $self->mysql_data_dir,
			 target  => $self->target_db,
			 symlink => 'autocomplete',        # assumes config files are up-to-date as g_species -> g_species_release!
		     });

  my $fh = $self->master_log;
  print $fh $self->step . " complete...\n";  
}


sub create_db {
    my $self = shift;
    
    my $user    = $self->mysql_user;
    my $pass    = $self->mysql_pass;
    my $target_db  = $self->target_db;

    my $a = WormBase::Autocomplete->new($target_db,$user,$pass);
    $a->init;
    
    system("mysql -u $user -p$pass -e 'grant all privileges on $target_db.* to nobody\@localhost'");
}


1;
