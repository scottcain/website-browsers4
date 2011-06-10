#!/bin/bash

# Mirror the Sanger FTP site
# Check once at midnight every night.

# Pull in my configuration variables shared across scripts
source ../../update.conf

cd $FTP_RELEASES_DIR

# -r     recursive
# -N     don't download newer files
# -l 10  maximum depth
# -nH    omit the host from the local directory
# --cut-dirs=3    Is this the right amount when mirroring from root?
wget -r -N -nH -l 20 --cut-dirs=3 ftp://ftp.sanger.ac.uk/pub2/wormbase/releases
