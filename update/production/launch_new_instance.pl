#!/usr/bin/perl

use strict;
use VM::EC2;
use Net::OpenSSH;
use Getopt::Long;

my ($release,$ami_id,$help);
GetOptions('release=s' => \$release,
	   'ami_id=s'  => \$ami_id,
	   'help=s'    => \$help,
    );

if ($help || (!$release && !$ami_id)) {
    die <<END;

Usage: $0 --release WSXXX --ami_id ami-4e50f127

Launch a new instance of the WormBase site on the Amazon cloud.
By default will use an m1.large instance.

END
;
}


my $access_key = $ENV{EC2_ACCESS_KEY};
my $secret_key = $ENV{EC2_SECRET_KEY};

# get new EC2 object
my $ec2 = VM::EC2->new(-access_key => $access_key,
		       -secret_key => $secret_key,
		       -endpoint   => 'http://ec2.amazonaws.com') or die "$!";

# The core image ID is hard-coded here. But it will change from release to release.
# Need to discover what it is.
my $image       = $ec2->describe_images($ami_id);
my $instance    = $ec2->run_instance({-instance_type => 'm1.large'});

# wait for both instances to reach "running" or other terminal state
$ec2->wait_for_instances([$instance]);
my $instance_id = $instance->instanceId; 
my $hostname    = $instance->publicDNS;


# Get a list of all available volumes
my @volumes = $ec2->describe_volumes;
for my $vol (@volumes) {
    
    if ($vol->Version eq $release && $vol->status eq 'available') {	
	my $a = $volume->attach($instanceId,'/dev/sdg');
	while ($a->current_status ne 'attached') {
	    sleep 2;
	}
	print "volume is ready to go\n";
	copy_data($vol,$hostname);

# Detach the volume from the instance
	my $attachment = $vol->detach({-instance_id => $instance_id });
	while ($attachment->current_status ne 'detached') {
	    sleep 2;
	}
	
    }

    # Finally, start services on the machine
    my $ssh = $self->ssh($hostname);
    $ssh->system("saceclient localhost -port 2005");
    $ssh->system("cd /usr/local/wormbase/website/production ; ./script/wormbase-init.sh start");    
}

sub copy_data {
    my ($vol,$hostname) = @_;
    my $volume_id = $vol->volumeId;
    
# Volume ready?  Log-in and start setting it up.
    my $ssh = $self->ssh($hostname);
    
# Mount my EBS volume
    $ssh->system("sudo mount /dev/xvdg /mnt/ebs");
    
# Create some target directories on ephemeral storage.
    $ssh->system("sudo mkdir /mnt/ephemeral0/wormbase");
    $ssh->system("sudo chmod 2775 /mnt/ephemeral0/wormbase");
    $ssh->system("sudo mkdir /mnt/ephemeral1/mysql");
    $ssh->system("sudo chown mysql:mysql /mnt/ephemeral1/mysql");
    $ssh->system("sudo chmod 2775 /mnt/ephemeral1/mysql");
    
# Create some symbolic mounts
    $ssh->system("sudo mount /usr/local/wormbase /mnt/ephemeral0/wormbase");
    $ssh->system("sudo mount /var/lib/mysql /mnt/ephemeral1/mysql");
    
# Copy EBS contents to ephemeral storage
    $ssh->system("cp -rp /mnt/ebs/wormbase/* /mnt/ephemeral0/wormbase/.");
    $ssh->system("cp -rp /mnt/ebs/mysql/* /mnt/ephemeral1/mysql/.");
    
# Unmount the volume
    $ssh->system("sudo umount /mnt/ebs");
    
}

sub ssh {
    my $node;
#    my $manager = $self->production_manager;
    my $manager = 'tharris';
    my $ssh = Net::OpenSSH->new("$manager\@$node");
    $ssh->error and die "Can't ssh to $manager\@$node: " . $ssh->error;	
    return $ssh;
}

