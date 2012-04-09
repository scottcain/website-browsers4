package WormBase::Update::Production::DeployWebapp;

# TODO:

# Run tests BEFORE updating the symlink, to trap cases like where we have missing modules.
# eg: hg pull -u && prove -l t && sudo /etc/init.d/apache2 restart

# Installing modules (or rsync them)
# ssh $NODE "cd /usr/local/wormbase/website/production; source wormbase.env; perl Makefile.PL; make installdeps"

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'deploying a new version of the webapp',
);



has 'pm_version' => (
    is => 'ro',
    lazy_build => 1
    );

sub _build_pm_version {
    my $self = shift;
    my $staging_dir = $self->app_staging_dir;
    my $version_string = `grep  VERSION $staging_dir/lib/WormBase/Web.pm`;
    chomp $version_string;
    my ($software_version) = $version_string =~ /our \$VERSION = \'(....)\'/;
    return $software_version;
}


has 'git_commits' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_git_commits {       
    my $self = shift;
    chdir($self->app_staging_dir);
    my $revision = `git describe`;
    chomp $revision;
    my ($ws,$commits,$hash) = split("-",$revision);
    $commits ||= '0';
    return $commits;
}

has 'git_cumulative_commits' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_git_cumulative_commits {       
    my $self = shift;
    chdir($self->app_staging_dir);
    my $commits = `git shortlog | grep -E '^[ ]+\\w+' | wc -l`;
    chomp $commits;
    return $commits;
}


has 'app_version' => (
    is => 'ro',
    lazy_build => 1);

sub _build_app_version {
    my $self = shift;

    # Getting the version from localhost doesn't work. It may be running a version > than production.
    # Maybe get the current production version from rest instead?
    # In THIS case, we are using the supplied release.
    my $release = $self->release;  

    my $software_version  = $self->pm_version;
#    my $software_revision = $self->git_cumulative_commits;
    my $software_revision = $self->git_commits;
    my $date = `date +%Y.%m.%d`;
    chomp $date;
    
    my $dir = "$release-$date-v${software_version}r$software_revision";
    return $dir;
}

########################################################

sub run {
    my $self = shift;
    $self->dump_version_file;
#    $self->rsync_staging_directory;    
    $self->pull_webapp;
#    $self->create_environment_file;
    $self->create_software_release;
    $self->save_production_reference;
}




sub dump_version_file {
    my $self    = shift;
    $self->log->info('dumping software version file');

    chdir($self->app_staging_dir);

    # Getting the version from localhost doesn't work. It may be running a version > than production.
    # Maybe get the current production version from rest instead?
#    my $release = $self->production_release;  

    my $software_version = $self->pm_version;
    my $software_commits = $self->git_commits;
    my $software_commits_running = $self->git_cumulative_commits;
    
    my $date = `date +%Y.%m.%d`;
    chomp $date;

    # Before syncing, dump a small file with these versions.
    $self->system_call("cat /dev/null > VERSION.txt","cat /dev/null > VERSION.txt",'creating version file');
    open OUT,">VERSION.txt";
    print OUT <<END;
DATE=$date
SOFTWARE_VERSION=$software_version
COMMITS_SINCE_TAG=$software_commits
COMMITS_CUMULATIVE=$software_commits_running
VERSION_STRING="v{$software_version}r${software_commits}"
END
close OUT;
}
#DATABASE_VERSION=$release


# The WormBase environment file
sub create_environment_file {
    my $self = shift;
    $self->log->info('create environment file');
    my ($local_nodes)  = $self->local_app_nodes;
    my ($remote_nodes) = $self->remote_app_nodes;

    my $app_root    = $self->wormbase_root;
    my $app_version = $self->app_version;
    
    open OUT,">/tmp/wormbase.env";
    print OUT <<'END';
#!/bin/sh

# The directory that contains your checked out source
export APPROOT=/usr/local/wormbase/website

# This is a symbolic name of the application corresponding
# to its directory on the file system at $APPROOT/$APP
export APP=production    # eg, tharris, acabunoc, staging, production

# Number of workers to launch.
export WORKERS=10

# When testing behind a reverse proxy, this port should
# correspond to your assigned virtual host
# todd.wormbase.org: 9001
# abby.wormbase.org: 9002
# xshi.wormbase.org: 9003
# staging.wormbase.org: 5000
export PORT=5000

# To daemonize the server, uncomment and set to true.
#export DAEMONIZE=
export ENVIRONMENT=development

# Location of your local::lib Perl libaries.
# Here, assumed to be at $APPROOT/$APP/extlib.
# Adjust as necessary.
export PERL5LIB="$APPROOT/$APP/extlib/lib/perl5:$APPROOT/$APP/extlib/lib/perl5/x86_64-linux-gnu-thread-multi:$APPROOT/$APP/lib:$APPROOT/$APP/extlib/gbrowse2/current/lib/perl5/x86_64-linux-gnu-thread-multi:$PERL5LIB"
export MODULEBUILDRC="$APPROOT/$APP/extlib/.modulebuildrc"
export PERL_MM_OPT="INSTALL_BASE=$APPROOT/$APP/extlib"
export PATH="$APPROOT/$APP/extlib/bin:$PATH"
END
;
    close OUT;

    foreach my $node (@$local_nodes,@$remote_nodes) {
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	$ssh->system("cd $app_root/website/$app_version; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\\[% app %\\]/production/g' wormbase.env")
	    or $self->log->logdie("couldn't fix the environment file");	
    }
}

sub rsync_staging_directory {
    my $self = shift;

    $self->log->info('deploying software');
    my ($local_nodes)  = $self->local_app_nodes;
    my ($remote_nodes) = $self->remote_app_nodes;

    my $app_root = $self->wormbase_root;
    my $app_version = $self->app_version;
    my $staging_dir = $self->app_staging_dir;    

    # Syncing to an NFS mount?
    if (0) {
	my $nfs_server = $self->local_nfs_server;
	my $nfs_root   = $self->local_nfs_root;

	$self->log->debug("rsync staging to nfs: $nfs_server");
	my $ssh = $self->ssh($nfs_server);
	$ssh->error && $self->log->logdie("Can't ssh to $nfs_server: " . $ssh->error);
    
	$ssh->system("mkdir $nfs_root/website/$app_version") or $self->log->logdie("Couldn't create a new app version on $nfs_server: " . $ssh->error);
	$self->system_call("rsync -Ca --exclude tmp --exclude .hg --exclude extlib $staging_dir/ $nfs_server:$nfs_root/website/$app_version",'rsyncing staging directory into production');


	# Should also rsync our libraries from web6 across
	# rsync -Cav extlib/ wb-web10.oicr.on.ca:/usr/local/wormbase/extlib

	# Update the symlink.  Here or part of GoLive?
	$ssh->system("cd $nfs_root/website ; rm production ;  ln -s $app_version production")
	    or $self->log->logdie("Couldn't update the production symlink");
    }

#    foreach my $node (@$remote_nodes) {
    foreach my $node (@$local_nodes,@$remote_nodes) {
	$self->log->info("   deploying the staging directory to $node");
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);

	# Approach 1: each deployment push is a new directory.
	if (0) {
	    $ssh->system("mkdir $app_root/website/$app_version") or $self->log->warn("Couldn't create a new app version on $node: " . $ssh->error);
	    $self->system_call("rsync -Ca --exclude logs --exclude tmp --exclude .hg --exclude extlib.tgz --exclude wormbase.env --exclude extlib $staging_dir/ ${node}:$app_root/website/$app_version",'rsyncing staging directory into production');
	    # Update the symlink.  Here or part of GoLive?
	    $ssh->system("cd $app_root/website; mkdir $app_root/website/$app_version/logs ; chmod 777 $app_root/website/$app_version/logs ; rm production;  ln -s $app_version production")
		or $self->log->warn("Couldn't update the production symlink");	    
	}
	
	# Approach 2: simply rsync to the production directory.
	# First back up production.
	$ssh->system("cp -r /usr/local/wormbase/website/production /usr/local/wormbase/website/archive/$app_version")
	    or $self->log->warn("Couldn't back up the current production directory to $node:website/archive/$app_version");
	$self->system_call("rsync -Ca --exclude logs --exclude tmp --exclude .hg --exclude extlib.tgz --exclude wormbase.env --exclude extlib $staging_dir/ ${node}:$app_root/website/production",'rsyncing staging directory into production');		
	$self->send_hup_to_starman($ssh,$node);
    }
}



sub pull_webapp {
    my $self = shift;

    $self->log->info('pulling code changes onto new nodes');

    my $app_root = $self->wormbase_root;
    my $app_version = $self->app_version;

    my $target  = $self->target;


    my ($app_nodes) = $self->target_nodes('app');
    # $self->package_mysql() if ($self->method eq 'by_package');
    foreach my $node (@$app_nodes) {
	$self->log->info("   pulling new code onto $node");
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	
	$ssh->system("cp -r /usr/local/wormbase/website/production /usr/local/wormbase/website/archive/$app_version")
	    or $self->log->warn("Couldn't back up the current production directory to $node:website/archive/$app_version");

	$ssh->system("cd /usr/local/wormbase/website/production ; git pull")
	    or $self->log->warn("Couldn't pull onto $node from the git repository");

	$self->send_hup_to_starman($ssh,$node);
    }
}


sub create_software_release {
    my $self = shift;
    $self->log->info('creating software release');
    my $wormbase_root = $self->wormbase_root;
    my $app_version   = $self->app_version;
    
    $self->system_call("cp -r $wormbase_root/website/staging /usr/local/ftp/pub/wormbase/software/$app_version",'creating software release');
    chdir($self->ftp_root . "/software");
    $self->system_call("tar czf $app_version.tgz  --exclude 'logs' --exclude '.hg' --exclude 'extlib' --exclude 'wormbase_local.conf' $app_version",'tarring software release');
    $self->system_call("rm -rf $app_version",'removing app version');
    $self->update_symlink({target => "$app_version.tgz",
			   symlink => 'current.tgz'});
}



sub save_production_reference {
    my $self = shift;
    $self->log->info('saving production reference');
    my $wormbase_root = $self->wormbase_root;
    chdir("$wormbase_root/website");
    my $staging_dir = $self->app_staging_dir;
    $self->system_call("rm -rf production.current",'removing the old production version');
    $self->system_call("cp -r $staging_dir production.current",'saving a reference of the current production version');
}


sub send_hup_to_starman {
    my ($self,$ssh,$node) = @_;
    $self->log->info("   sending HUP to starman on $node");
    $ssh->system("kill -HUP `head -1 /tmp/production.pid`");
}




1;
