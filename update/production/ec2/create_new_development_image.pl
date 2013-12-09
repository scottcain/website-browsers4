#!/usr/bin/perl

# From the existing development instance:
# 1. create a new image. 
# 2. launch a new development instance
# 3. reassign the elastic IP address to it.
# 4. stop the old instance
# 5. Clean up.

# Create a NEW build image from a currently running instance
# tagged with Role:Build

use strict;
use VM::EC2;
use Getopt::Long;

my ($release,$help);
GetOptions('release=s'     => \$release,
	   'help=s'        => \$help,
    );


if ($help || (!$release)) {
    die <<END;
    
Usage: $0 --release WSXXX

Create a new image of the current development instance.

Options:
  --release     required. The WSXXX version hosted on the instance.
                          Typically the version moving to production.

END

}

# Connect to EC2 ; access_key and secret_key provided by ENV
my $ec2 = VM::EC2->new(-endpoint    => 'http://ec2.amazonaws.com',
		       -print_error => 1);

# Discover the current QAQC environment instance.
# Hopefully it exists.
my @i = $ec2->describe_instances({'tag:Status' => 'development' });

if (@i > 1) { 
    print STDERR <<END;

        Um. 
	There seem to be multiple development instances running at the moment. 
	There should only be one. Please kill some of the extras and re-run.
	The running instances are:

END
print join("\t\n",@i);
    die;
}

# Okay, we only have a single instance.
my $instance = $i[0];

my $date = `date +%Y-%m-%d`;
chomp $date;

# Now that I have the instance, create a new AMI from it with appropriate tags.
print STDERR "Creating a new image of $instance...\n";
my $image = $instance->create_image(-name        => "wb-development-$date",
				    -description => 'the wormbase development environment',
    );

# Wait until the production image is complete.
while ($image->current_status eq 'pending') {
    sleep 5;
}

# Add some tags.
$image->add_tags( Name        => "wb-development",
		  Description => "wormbase development image autocreated from $instance",
		  Status      => 'development',
		  Role        => 'dev-server',
		  Date        => $date,
		  Release     => $release,
		  Project     => 'WormBase',
		  Client      => 'OICR',
		  Image       => $image,
    );


tag_snapshots($image,$date);

print STDERR <<END

A new development image has been created with ID: $image.

You may wish to delete the old instance: $instance.

--

END
;


# Tag snapshots associated with this image.
# We fetch all snapshots, then look for those with a description
# matching our current image_id. (This could also be via a filter)
sub tag_snapshots {
    my ($image,$date) = @_;    
    my @all_snaps = $ec2->describe_snapshots();
    my @these_snapshots;
    foreach my $snapshot (@all_snaps) {
	if ($snapshot->description =~ /$image/) {  # taken here to be image_id.
	    push @these_snapshots,$snapshot;
	}
    }
    
    # Got 'em. Tag 'em.
    foreach my $snapshot (@these_snapshots) {
	print STDERR "\ttagging $snapshot...\n";
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
		       -tag         => { Name        => "wb-development-$name",
					 Description => "$name volume for development image $image",
					 Status      => 'development',
					 Role        => 'development',
					 Release     => $release,
					 Project     => 'WormBase',
					 Client      => 'OICR',
					 Date        => $date,
					 Image       => $image,
		       });	
    }
}
