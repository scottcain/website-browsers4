package Update::PackageDatabases;

use strict;
use base 'Update';
use Digest::MD5;

my $packages = {
		acedb => { fileroot => 'acedb_%s.ace',
			   source   => '/usr/local/acedb', # Root dir containing files to be pacakaged
			   contents => ['elegans_%s'],
			   exclude  => ['database/oldlogs','database/serverlog.wrm',
					'database/log.wrm','database/serverlog.wrm*'] },		
		elegans_gff => { fileroot => 'c_elegans_%s.gff',
				 contents => [qw/c_elegans c_elegans_pmap c_elegans_gmap/],
				 exclude  => ['*bak*'] },
		briggsae_gff => { fileroot => 'c_briggsae_%s.gff',
				  contents => [qw/c_briggsae/],
				  exclude  => ['*bak*'] },
		remanei_gff => { fileroot => 'c_remanei_%s.gff',
				  contents => [qw/c_remanei/],
				  exclude  => ['*bak*'] },
		japonica_gff => { fileroot => 'c_japonica_%s.gff',
				  contents => [qw/c_japonica/],
				  exclude  => ['*bak*'] },
		brenneri_gff => { fileroot => 'c_brenneri_%s.gff',
				  contents => [qw/c_brenneri/],
				  exclude  => ['*bak*'] },
		p_pacificus_gff => { fileroot => 'p_pacificus_%s.gff',
				  contents => [qw/p_pacificus/],
				  exclude  => ['*bak*'] },
		b_malayi_gff => { fileroot => 'b_malayi_%s.gff',
				  contents => [qw/b_malayi/],
				  exclude  => ['*bak*'] },
	       };


# The symbolic name of this step
sub step { return 'packaging databases'; }

sub run {
  my $self = shift;
  $self->create_packages();
  $self->update_symlink({path    => $self->tarballs_dir,
			 target  => $self->release,
			 symlink => 'current-release',
			});
  my $fh = $self->master_log;
  print $fh $self->step . " complete...\n";
}


# Create flat archives, not one relative to /usr/local/acedb
# since I may be unpacking / moving to different locations.
sub create_packages {
  my $self = shift;

  my $release    = $self->release;
  my $tarballs   = $self->tarballs_dir;
  my $base       = "$tarballs/$release";
  $self->_make_dir($tarballs);
  $self->_make_dir($base);

  my $release    = $self->release;
  my $mysql_data = $self->mysql_data_dir; 
  
  foreach (keys %$packages) {
    $self->logit->debug("package $_");
    my $fileroot = sprintf($packages->{$_}->{fileroot},$release);
    my $target   = $fileroot . '.tgz';
    my $source   = $packages->{$_}->{source};
    $source ||= $self->mysql_data_dir;

    my $contents;
    if ($_ =~ /acedb/) {	
      $contents = join(' ',map { sprintf($_,$release) } @{$packages->{$_}->{contents}});
    } else {
      $contents = join(' ',map { $_ . "_$release" } @{$packages->{$_}->{contents}} );
    }
    my $excludes = join(' ',map { "--exclude '$_'" } @{$packages->{$_}->{exclude}});
    my $command = <<END;
tar -czf $base/$target -C $source $contents $excludes
END
;

    $self->logit->debug("packaging $contents via cmd: $command");
    system($command) == 0 or die "Couldn't package $fileroot for $release: $!\n";
    create_md5($base,$fileroot);
  }
}

sub create_md5 {
  my ($base,$file) = @_;

  open(FILE, "$base/$file.tgz") or die "Can't open '$base/$file.tgz': $!";
  binmode(FILE);

  open OUT,">$base/$file.md5";
  print OUT Digest::MD5->new->addfile(*FILE)->hexdigest, "  $file.tgz\n";

  # Verify the checksum...
  chdir($base);
  my $result = `md5sum -c $file.md5`;
  die "Checksums do not match: packaging $file.tgz failed\n" if ($result =~ /failed/);
}


1;
