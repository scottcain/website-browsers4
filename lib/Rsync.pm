package Rsync;

use strict;
use vars qw/@ISA @EXPORT/;

require Exporter;
@ISA  = 'Exporter';

@EXPORT = (qw/rsync homedir format_exclude/);

sub rsync {
  my $files = shift;
  # Commands will be run as the appropriate user to avoid having to
  # execute rsync commands as root
  #  my $status = system "rsync -Cavz $fromto"; 
  # This expects that the script will already been run as root/sudo
  #  my $status = system "sudo -u $USER rsync -Cav $fromto";  # "z" flag has been giving problems!
  warn "copying $files\n";
  my $status = system "rsync -Cav $files";  # "z" flag has been giving problems!
  return if $status == 0;
  return if $status >> 8 == 23;  # various can't set permission errors
  croak("Couldn't run rsync: status code = ",$status>>8);
}

sub homedir {
  my $user = shift;
  my $dir  = (getpwnam($user))[7];
  $dir or die "Unknown user $user\n";
  $dir;
}

sub format_exclude {
  my $list = shift;
  my $exclude = join(" ",map {"--exclude='$_'" } @$list);
  return $exclude;
}

1;
