# THIS INSTALL SCRIPT IS NOT YET DONE!


#!/usr/bin/perl

# WormBase Virtual Machine fetcher/installer

# TODO:
# Write out install by package script
# Checking of disk sizes
# Fetching and checksum


use strict;
use Digest::MD5;

use constant LIVE_VERSION_CGI => 'http://www.wormbase.org/db/misc/version';
use constant DEV_VERSION_CGI  => 'http://dev.wormbase.org/db/misc/version';
use constant VM_REPOSITORY    => 'ftp://ftp.wormbase.org/pub/wormbase/people/tharris/vmx';

# this script should be automatically created by the package script!

# Core components are all found in ${VERSION}/databases (although not all are required!)
my @core_components = [ acedb       => { tgz  => '%s-acedb.tgz',
					 md5  => '%s-acedb.md5',
					 description =>'',
					 tarball_disk_space => '',
					 unpacked_disk_space => '',
					 status => 'required',
				     },
			elegans     => { tgz  => '%s-c_elegans.tgz',
					 md5  => '%s-c_elegans.md5',
					 description =>'',
					 tarball_disk_space => '',
					 unpacked_disk_space => '',
					 status => 'required',
				     },
			other_species => { tgz => '%s-other_species.tgz',
					  md5 => '%s-other_species.md5',
					  description =>'',
					  tarball_disk_space => '',
					  unpacked_disk_space => '',
					  status => 'optional',
				      },
			support        => { tgz => '%s-support.tgz',
					  md5 => '%s-support.md5',
					  description =>'',
					  tarball_disk_space => '',
					  unpacked_disk_space => '',
					  status => 'optional',
				      },
			autocomplete => { tgz => '%s-autocomplete.tgz',
					  md5 => '%s-autocomplete.md5',
					  description =>'',
					  tarball_disk_space => '',
					  unpacked_disk_space => '',
					  status => 'optional',
				      },
			];


interrogate();

# Fetch the current versions
my $installed    = local_version();
my $dev_version  = development_version();
my $live_version = live_version();

if ($live{version} eq '') {
    print <<END;
********************************************************************
  WARNING: Could not determine live/dev versions
********************************************************************
Update aborted because checking for the current live and development
versions failed. You must be online to update your WormBase
installation.
END
die;
}

print "LIVE SITE ($live{url})\n";
print "----------------------------\n";
print_keys(\%live);

print "DEV SITE ($dev{url})\n";
print "----------------------------\n";
print_keys(\%dev);

print "LOCAL INSTALLATION (~/WormBase)\n";
print "----------------------------\n";
print_keys(\%local);



# The desired version, fetched automatically or provided with --version

my $uptodate;
if ($local{version} eq $live{version}) {
    $uptodate++;
}

if ($uptodate) {
    print "Your WormBase Virtual Machine is already up-to-date: running $live{version}\n\n";
} else {

  #    # Fetch the appropriate components according to the user selections
  #    foreach (@selected_components) {
  #	fetch_component($_);
  #    }
}



# Iterate over available components, asking users which they would like to install
# For optional components that are NOT selected, fetch a dummy vmdk in their place
# to keep the .vmx file from breaking
sub interrogate {
    my %desired_options;
    foreach my $hash (@core_components) {
	if ($hash->{status} eq 'required') {
	    push @{$desired_options->{components}},$_;
        } else {
  	  # Get the description
	  # Check the packed / available space
	  # Check the unpacked / available space
	  # Bomb out if not enough space
	  # Stash the symbolic name for later fetching
	  push @{$desired_options->{components}},$_;
       }
    }

    # Also need to ask about path, purging tarballs, purging old releases.
    return \%desired_options;
}


# Fetch the local installed version
sub local_version {
    my $path "~/Wormbase/elegans";
    my ($realdir,$modtime) = read_symlink($path);
    my ($installed) = $realdir =~ /(WS\d+)$/;
    $installed = ($installed) ? $installed : 'none_installed';
    
    my $hostname = Sys::Hostname::hostname();
    my %response = ( title   => 'WormBase, the C. elegans database',
		     site     => "local installation at $path",
		     version  => $installed,
		     released => $modtime,
		     status   => ($installed ne 'None installed') ? 'SUCCESS' : $installed,
		     url      => $hostname,
		     );
    return (wantarray ? %response : $response{version});
}


sub live_version {
  my $response = $self->_check_version(LIVE_VERSION_CGI);
  $response->{url} = $url;
  return (wantarray ? %$response : $response->{version});
}

sub development_version {
  my $self = shift;
  my $defaults = $self->defaults;

  my $url      = $defaults->development_server->{version_cgi};
  my $response = $self->_check_version($url);
  $response->{url} = $url;
  return (wantarray ? %$response : $response->{version});
}


# Read the contents of a provided symlink (or path) to parse out a version
# Returning the full path the symlink points at, the installed version
# and its modtime
sub read_symlink {
    my ($self,$path) = @_;
    my $realdir = -l $path ? readlink $path : $path;
    my ($root) = $path =~ /(.*\/).*/;
    my $full_path = $root . "/$realdir";
    my @temp = stat($full_path);
    my $modtime = localtime($temp[9]);
    return ($realdir,$modtime);
}

sub _check_version {
  my ($self,$url) = @_;
  my $defaults = $self->defaults;
  my $installed_version = $self->local_version('~/WormBase/current_version');

  my $ua  = LWP::UserAgent->new();
  my $hostname = Sys::Hostname::hostname();
  $ua->agent("WormBase::VirtualMachines-$hostname/$installed_version");
  my $request  = HTTP::Request->new('GET',$url) ;
  my $response = $ua->request($request);
  my %response;
  if ($response->is_success) {
    # Parse out the content
    my $content = $response->content;
    my $parsed = XMLin($content);
    foreach (keys %{$parsed}) {
      $response{$_} = $parsed->{$_};
    }
    $response{status} = "SUCCESS";
  } else {
    $response{error} = "FAILURE: Couldn't check version: " . $response->status_line;
  }
  return \%response;
}

sub fetch_component {
    my ($symbolic_name,$version) = @_;
    
    # Where to find the database tarballs.
    my $ftp_site  = VM_REPOSITORY;
    
    # The component tarball
    my $file  = sprintf($components->{$symbolic_name}->{tgz},$version);
    my $md5   = sprintf($components->{$symbolic_name}->{md5},,$version);
    
    # Local and remote paths
    # Is a path fragment specified? If so use that one.
    # If not, assume that we are in the version/databases dir
    my ($remote_path,$remote_path_md5);
    if (my $path = $components->{$symbolic_name}->{path}) {
	$remote_path     = "$ftp_site/$path/$file";
	$remote_path_md5 = "$ftp_site/$path/$md5";	
    } else {
	$remote_path     = "$ftp_site/$version/databases/$file";
	$remote_path_md5 = "$ftp_site/$version/databases/$md5";
    }
    
    


    # DONE TO HERE.  DOWNLOAD PATH WILL BE SPECIFIED IN THE INTEROGATE
    my $dl_path         = $defaults->tmp_dir . "/$version";
    my $install_path    = eval { $defaults->components->{$component}->{install_path} };
        
    $self->prepare_tmp_dir(-path=>$dl_path);

    # Make sure there is enough space first
    my $dl_disk_space     = $defaults->components->{$component}->{download_space};
    $self->check_disk_space(-path      => $dl_path,
			    -required  => $dl_disk_space,
			    -component => $component);
    
    my $unpacked_disk_space = $defaults->components->{$component}->{unpacked_space};
    $self->check_disk_space(-path      => $install_path,
			    -required  => $unpacked_disk_space,
			    -component => $component);
    
    # Using wget
    chdir($dl_path);
    my $result     = system("wget -c ftp://$ftp_site${remote_path}");
    my $md5_result = system("wget -c ftp://$ftp_site${remote_path_md5}");
    
    checksum($dl_path,$file,$md5);
    return undef if $result != 0;  # Remember, this is a system command
    return "$dl_path/$file";
}



# Do an MD5 checksum of downloaded tarballs
sub checksum {
    my ($localpath,$downloaded_file,$md5) = @_;
    
    $self->logit(-msg=>"Checksumming $downloaded_file...");
    
    chdir($localpath);
    open(FILE, $downloaded_file) or die "Can't open '$downloaded_file': $!";
    binmode(FILE);
  my $downloaded_md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
    
    my $raw_md5 = `cat $md5`;
    chomp $raw_md5;
    my ($expected_md5) = $raw_md5 =~ /(.*)\s+.*/;
    $expected_md5 =~ s/ //g;
    # print "md5 checksum debug: $downloaded_md5 $expected_md5\n";
    if ($downloaded_md5 ne $expected_md5) {
	unlink($downloaded_file) || die;
	$self->logit(-msg => "Check sum of $downloaded_file failed (download failed). Exiting.",
		     -die => 1);
    } else {
	$self->logit(-msg      => "Check sum of $downloaded_file succeeded");
    }
}
