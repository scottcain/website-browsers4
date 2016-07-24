package WormBase::Update::EC2;

# Helper methods for EC2 interactions.

use Time::HiRes qw(gettimeofday tv_interval);
use VM::EC2;
use Moose;
use FindBin qw($Bin);
use JSON::Any qw/XS JSON/;

extends qw/WormBase::Update/;
with qw/WormBase::Roles::Config/;

# Both are provided by env
has 'secret_key' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_secret_key {
    my $self = shift;
    return $ENV{EC2_SECRET_KEY},
}

has 'access_key' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_access_key {
    my $self = shift;
    return $ENV{EC2_ACCESS_KEY},
}


has 'endpoint' => (
    is => 'ro',
    default => 'http://ec2.amazonaws.com',
    );

# Lib::VM::EC2
has 'ec2' => (
    is => 'rw',
    lazy_build => 1);

sub _build_ec2 {
    my $self = shift;

# Connect to EC2 ; access_key and secret_key provided by ENV
    my $ec2 = VM::EC2->new(-endpoint    => $self->endpoint,
			   -print_error => 1);
    return $ec2;
}


# QUick access to specific resources
# The ID of the build image
has 'build_image' => (
    is => 'rw',
    lazy_build => 1);

sub _build_build_image {
    my $self = shift;
    
    my $i = $self->get_images({'tag:Status' => 'build'});
    
    if (@$i > 1) { 
	$self->log->warn("There seem to be multiple build AMIs. There can be only one. They are:");
	$self->display_image_metadata($i);
	die;
    }
    
# Okay. We only have one.
    my $build_image = $i->[0];
    return $build_image;
}


# Fetch the core image for the provided release
has 'qaqc_image' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_qaqc_image {
    my $self = shift;
    my $ec2  = $self->ec2;
    
    my $i = $self->get_images({'tag:Status' => 'qaqc',
			       'tag:Release' => $self->release, });
    
    if (@$i > 1) { 
	my $release = $self->release;
	$self->log->warn("There seem to be multiple core AMIs for $release. There can be only one. They are:");
	$self->display_image_metadata($i);
	die;
    }
   

    # Okay, we only have a single instance.
    my $image = $i->[0];
    return $image;
}


# Fetch the core image for the provided release
has 'production_image' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_production_image {
    my $self = shift;
    my $ec2  = $self->ec2;
    
    my $i = $self->get_images({'tag:Status' => 'production',
			       'tag:Role'   => 'webapp',
			       'tag:Release' => $self->release,
			      });
    
    if (@$i > 1) { 
	my $release = $self->release;
	$self->log->warn("There seem to be multiple production AMIs for $release. There can be only one. They are:");
	$self->display_image_metadata($i);
	die;
    }
    
    # Okay, we only have a single instance.
    my $image = $i->[0];
    return $image;
}



# --------

sub display_instance_metadata {
    my ($self,$i,$format) = @_;
    $format ||= 'short';
       
    foreach my $i (@$i) {	
	my $id         = $i->instanceId; 
	my $type       = $i->instanceType;
	my $state      = $i->instanceState;
	my $status     = $i->current_status;
	my $zone       = $i->availabilityZone;
	my $launched   = $i->launchTime;
	my @groups     = $i->groups;
	my $tags       = $i->tags;
	
	# Network information
	my $hostname   = $i->dnsName;
	my $private_ip = $i->privateIpAddress;
	my $public_ip  = $i->ipAddress;
	
	# EBS volumes
	# my $block_dev  = $meta->blockDeviceMapping; # a hashref

#	# Pepper our environment. Optional...
#	system('export WBSERVER$c="' . $hostname . '"');
	
	if ($format eq 'short') {
	    print "  $hostname ($tags->{Status}: $tags->{Role}; $state)\n";
	} else {
	    print "  Instance: $id ($hostname)\n";
	    print "\tprivate ip address: $private_ip\n";
	    print "\t public ip address: $public_ip\n";
	    print "\t    instance type : $type\n";
	    print "\t             zone : $zone\n";
	    print "\t            state : $state\n";
	    print "\t           status : $status\n";
	    print "\t              TAGS\n";
	    foreach (sort keys %$tags) { 
		print "\t                    $_ : $tags->{$_}\n";
	    }

	    print "\t              EBS mounts\n";
	    my @devices = $i->blockDeviceMapping;
	    foreach my $d (@devices) {
		my $virtual_device = $d->deviceName;
		my $volume_id      = $d->volumeId;
		print "\t                    $volume_id : $virtual_device\n";
	    }
	    
	    print "\n\n";
	}
    }
}


sub display_image_metadata {
    my $self   = shift;
    my $images = shift;
    foreach my $i (@$images) {
	my $id          = $i->imageId; 
	my $location    = $i->imageLocation;
	my $architecture = $i->architecture;
	my $kernel_id   = $i->kernelId;
	my $name        = $i->name;
	my $description = $i->description;
	my @bdm         = $i->blockDeviceMapping;
	my $tags        = $i->tags;
	
	print "\t$i\t " . $tags->{Description} . "\n";
    }
}

# Keep all of my heuristics for fetching various instances
# by a simple symbolic name in one place. I need to do this from 
# (consistently) for many different tasks.
# Status here is currently one of development|build|production.
# It corresponds to the tag "Status".
sub get_instances {
    my ($self,$params) = @_;
    
    my $ec2 = $self->ec2;
    
    # 'tag:Status'          => $status,
    
    $params->{'tag:Client'}          = 'OICR';
    $params->{'tag:Project'}         = 'WormBase';
    $params->{'instance-state-name'} = 'running';
    
    $self->log->info("\tfetching instances with the following parameters:\n"
		     . join("\n",map { "\t\t$_ = $params->{$_}" } keys %$params));   
    my @i = $ec2->describe_instances($params);
    return \@i;
}




# Fetch one (or many) images.
sub get_images {
    my $self   = shift;
    my $params = shift; 
    my $ec2    = $self->ec2;
    
    $params->{'tag:Client'}          = 'OICR';
    $params->{'tag:Project'}         = 'WormBase';

    $self->log->info("\tfetching images with the following parameters:\n"
		     . join("\n",map { "\t\t$_ = $params->{$_}" } keys %$params));   

    my @i = $ec2->describe_images($params);
    return \@i;
}



sub tag_instances {
    my $self    = shift;
    my $params  = shift;
    my $ec2 = $self->ec2;

    my $instances = $params->{instances};
    my $name      = $params->{name};
    my $release   = $self->release;

    my $date = `date +%Y-%m-%d`;
    chomp $date;
    
    $self->log->info("tagging instances with some metadata");
    
#			   Name        => "$name-$release-$instance",
    foreach my $instance (@$instances) {
	$ec2->add_tags(-resource_id => [ $instance ],
		       -tag => {
			   Name        => "$name",
			   Description => $params->{description},
			   Status      => $params->{status},
			   Role        => $params->{role},
			   Release     => $release,		     
			   Project     => 'WormBase',
			   Client      => 'OICR',
			   Date        => $date,
			   CreatedBy   => $params->{createdby},
			   Source_AMI  => $params->{source_ami},
		       });
	
    }
}


sub tag_images {
    my $self    = shift;
    my $params  = shift;
    my $ec2 = $self->ec2;

    my $image   = $params->{image};
    my $name    = $params->{name};
    my $release = $self->release;

    my $date = `date +%Y-%m-%d`;
    chomp $date;
    
    $self->log->info("tagging image with some metadata");
    
#			   Name        => "$name-$release-$instance",
    $ec2->add_tags(-resource_id => [ $image ],
		   -tag => {
		       Name        => "$name",
		       Description => $params->{description},
		       Status      => $params->{status},
		       Role        => $params->{role},
		       Release     => $release,		     
		       Project     => 'WormBase',
		       Client      => 'OICR',
		       Date        => $date,
		   });
    
}

# Tag snapshots associated with this image.
# We fetch all snapshots, then look for those with a description
# matching our current image_id. (This could also be via a filter)
sub tag_snapshots {
    my $self    = shift;
    my $params  = shift;

    my $date = `date +%Y-%m-%d`;
    chomp $date;
    
    my $ec2 = $self->ec2;
    
    my @all_snaps = $ec2->describe_snapshots();
    my @these_snapshots;
    my $image = $params->{images};
    
    # THIS IS BADLY BROKEN.
    # IT ENDS UP TAGGING ALL SNAPSHOTS.
    # Is image_id not defined?
    foreach my $snapshot (@all_snaps) {
	if ($snapshot->description =~ /$image/) {  # taken here to be image_id.
	    print join("\t",$snapshot->description,"--matched to--",$image),"\n";
	    push @these_snapshots,$snapshot;
	}
    }
    
    # Got 'em. Tag 'em.
    foreach my $snapshot (@these_snapshots) {
	$self->log->info("tagging $snapshot...");
	my $id = $snapshot->snapshotId;
	
	# Name and description are dynamic based on size of the snapshot.	
	# This is hard-coded logic for now.
	my $size = $snapshot->size;  # Units?
	my ($name);
	if ($size < 20) {
	    # This is the root volume.
	    $name = 'root';
	} elsif ($size > 600) {
	    # FTP
	    $name = 'ftp';
	} else {
	    $name = 'data';
	}
	
	$ec2->add_tags(-resource_id => [ $id ],
		       -tag         => { Name        => $params->{name} . "-$name",
					 Description => "$name volume for image $image",
					 Status      => $params->{status},
					 Role        => $params->{role},
					 Release     => $self->release,
					 Project     => 'WormBase',
					 Client      => 'OICR',
					 Date        => $date,
					 Source_ami  => $image,
		       });	
    }
}



sub tag_volumes {
    my $self    = shift;
    my $params  = shift;
    
    $self->log->info("tagging volumes with some metadata");
    
    my $ec2 = $self->ec2;
    
    my $instances = $params->{instances};
    my $release   = $self->release;

    my $date = `date +%Y-%m-%d`;
    chomp $date;
   
    # This works for build, which only has a single volume.
    foreach my $instance (@$instances) {
	
	# EBS volumes. There should only be one per instance.
	my @devices  = $instance->blockDeviceMapping; # a hashref
	
	foreach  my $d (@devices) {
	    my $virtual_device = $d->deviceName;
#	    my $snapshot_id    = $d->snapshotId;
#	    my $volume_size    = $d->volumeSize;
#	    my $delete         = $d->deleteOnTermination;     
	   
	    # Need the actual volume; cannot add tags to block device mappings
	    my $volume      = $d->volume;
	    my $volume_size = $volume->size;

	    # Name and description are dynamic based on size of the snapshot.	
	    # Hard-coded logic (for now).
	    my $type;
	    if ($volume_size < 20) {
		# This is the root volume.
		$type = 'root';
	    } elsif ($volume_size > 600) {
		# FTP
		$type = 'ftp';
	    } else {
		$type = 'data';
	    } 

	    $ec2->add_tags(-resource_id => [ $volume ],
			   -tag         => { Name        => $params->{name} . "-$type",   # will have something prepended in some cases.
					     Description => "$type volume for $instance $release",
					     Status      => $params->{status},
					     Role        => $params->{role} ? $params->{role} . "-$type" : $type,
					     Release     => $release,
					     Project     => 'WormBase',
					     Client      => 'OICR',
					     Date        => $date,
					     Attachment  => "$instance:$virtual_device",
			   });
	}
    }
}



sub associate_ip_address {
    my ($self,$instance,$ip) = @_;

    $self->log->info("Associating $ip to $instance.");
    
    my $ec2 = $self->ec2;

    # Dissociate the elastic IP (just to be safe);
    my $disassociate = $ec2->disassociate_address($ip);
    
    # Now associate
    my $associate = $ec2->associate_address($ip => $instance);
    if ($associate) {
	$self->log->info("Successfully associated $ip to $instance");    
    }    
}




# We want to use the INTERNAL IP of the FTP instance.
# Data transfer internally is free.
sub get_internal_ip_of_ftp_instance {
    my $self = shift;
    my $ec2  = $self->ec2;
    my @i = $ec2->describe_instances({'tag:Status' => 'development',
				      'tag:Role'   => 'dev-server'});
    
    if (@i > 1) { 
	my $msg = <<END; 
	There seem to be multiple development instances running at the moment.
	There should only be one. Please kill some of the extras and re-run.
	                  The running instances are:
END

	$msg .=  join("\t\n",@i);
	$self->log->logdie($msg);
    }
    
    my $instance = $i[0];
    my $ip = $instance->privateIpAddress;
    return $ip;
}






1;
