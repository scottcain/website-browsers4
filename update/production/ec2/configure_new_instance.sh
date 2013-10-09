#!/bin/bash

# Mount up ephemeral storage.
mount /mnt/ephemeral0
mount /mnt/ephemeral1

# Create bind mount targets
mkdir -p /mnt/ephemeral0/usr/local/wormbase

# This should *probably* be jenkins or a wormbase
# specific user.
chown -r tharris:wormbase /mnt/ephemeral0/usr

# Add SSH keys?


# Get acedb bin from S3.