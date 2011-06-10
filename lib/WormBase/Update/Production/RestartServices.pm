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
    my $release = $self->release;


    $self->log->info('restarting services');
    my ($local_nodes)  = $self->local_app_nodes;
    my ($remote_nodes) = $self->remote_app_nodes;

    my $app_root    = $self->wormbase_root;
    my $app_version = $self->app_version;
    
    foreach my $node (@$local_nodes,@$remote_nodes) {
	my $ssh = $self->ssh($node);
	$ssh->error && $self->log->logdie("Can't ssh to $node: " . $ssh->error);
	$self->restart_starman($node,$ssh);
	
    }
}



sub restart_starman {
    my ($self,$ssh) = @_;
    # Restart starman Here or in separate services module?
#    ssh $node "cd /usr/local/wormbase/website/production; source wormbase.env ; bin/starman-production.sh restart"

$ssh->system("cd $app_root/website/$app_version; cp wormbase.env.template wormbase.env ; perl -p -i -e 's/\\[% app %\\]/production/g' wormbase.env")
	    or $self->log->logdie("couldn't fix the environment file");	

    }
}





1;
