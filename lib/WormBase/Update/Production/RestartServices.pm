package WormBase::Update::Production::RestartServices;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => 'restarting services',
);

########################################################

sub run {
    my $self = shift;           
#    my $release = $self->release;

    $self->log->info('restarting services');
    my ($local_nodes)  = $self->local_app_nodes;
#    my ($remote_nodes) = $self->remote_app_nodes;
    
#    foreach my $node (@$local_nodes,@$remote_nodes) {
    foreach my $node (@$local_nodes) {
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);

	$self->restart_acedb($node,$ssh);
	$self->restart_mysql($node,$ssh);
	$self->restart_starman($node,$ssh);
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
