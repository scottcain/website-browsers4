#!/bin/bash

# Mirror the Sanger FTP site
# Check once at midnight every night.

cd /usr/local/ftp/pub/wormbase
# -r     recursive
# -N     don't download newer files
# -l 10  maximum depth
# -nH    omit the host from the local directory
# --cut-dirs=2    Is this the right amount when mirroring from root?
wget -r -N -nH -l 20 --cut-dirs=2 ftp://ftp.sanger.ac.uk/pub2/wormbase
