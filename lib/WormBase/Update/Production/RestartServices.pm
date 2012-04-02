package WormBase::Update::Production::RestartServices;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'restarting services',
);

has 'service' => (
    is => 'ro',
    );

########################################################

sub run {
    my $self = shift;           
    my $target  = $self->target;  # production, development, staging, mirror
    my $release = $self->release;

    $self->log->info('restarting services');

    my $service = $self->service;
    
    if ($service eq 'sgifaceserver') {
    ###################################
	# Acedb
	my ($acedb_nodes) = $self->target_nodes('acedb');	
	foreach my $node (@$acedb_nodes) {
	    my $ssh = $self->ssh($node);
	    $ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	    
	    $self->restart_acedb($node,$ssh);	    
	}
    }

    if ($service eq 'mysql') {
	###################################
	# MySQL
	my ($mysql_nodes) = $self->target_nodes('mysql');	
	foreach my $node (@$mysql_nodes) {
	    my $ssh = $self->ssh($node);
	    $ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	    
	    $self->restart_mysql($node,$ssh);
	}    
    }
    
    if ($service eq 'starman') {
	# This should be local_app_nodes, remote_app_nodes;
	my ($local_app_nodes) = $self->local_app_nodes();	
	push @{$local_app_nodes},$self->remote_app_nodes();
	foreach my $node (@$local_app_nodes) {
	    my $ssh = $self->ssh($node);
	    $ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	    
	    $self->restart_starman($node,$ssh);
	}
    }
}


sub restart_starman {
    my ($self,$node,$ssh) = @_;

    my $app_root    = $self->wormbase_root;
    $self->log->info("restarting starman on $node");
#    ssh $node "cd /usr/local/wormbase/website/production; source wormbase.env ; bin/starman-production.sh restart"

#    $ssh->system("cd $app_root/website/$app_version; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\\[% app %\\]/production/g' wormbase.env")
#	or $self->log->logdie("couldn't fix the environment file");	
    $ssh->system("cd $app_root/website/production; script/wormbase-init.sh stop ; sleep 5; killall -9 starman ; rm -f /tmp/production.pid ; script/wormbase-init.sh start")
	or $self->log->logdie("couldn't restart starman" . $ssh->error); 
}



sub restart_mysql {
    my ($self,$node,$ssh) = @_;

    $self->log->info("restarting mysqld on $node");
#    ssh $node "cd /usr/local/wormbase/website/production; source wormbase.env ; bin/starman-production.sh restart"

#    $ssh->system("cd $app_root/website/$app_version; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\\[% app %\\]/production/g' wormbase.env")
#	or $self->log->logdie("couldn't fix the environment file");	
    
    $ssh->system("sudo /etc/init.d/mysql restart")
	or $self->log->logdie("couldn't restart mysqld" . $ssh->error);	

}

sub restart_acedb {
    my ($self,$node,$ssh) = @_;

    $self->log->info("restarting sgifaceserver on $node");
#    ssh $node "cd /usr/local/wormbase/website/production; source wormbase.env ; bin/starman-production.sh restart"

#    $ssh->system("cd $app_root/website/$app_version; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\\[% app %\\]/production/g' wormbase.env")
#	or $self->log->logdie("couldn't fix the environment file");	
    
    $ssh->system("sudo killall -9 sgifaceserver");
#	&& $self->log->logdie("couldn't restart sgifaceserver" . $ssh->error);	

}





1;
