#!/bin/bash

# Mirror the Sanger FTP site
# Check once at midnight every night.

cd /usr/local/ftp/pub/wormbase
# -N don't download newer files
wget -r -N ftp://ftp.sanger.ac.uk/pub2/wormbase