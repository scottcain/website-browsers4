#!/bin/bash

# Fetch Wen's SPELL datasets to the primary WormBase FTP site
# once a release.

# Run from Jenkins using the Build Periodically option.
#    0 1 1 * *

cd /usr/local/ftp/pub/wormbase/datasets-wormbase/expression/spell
curl -O -X GET http://spell.caltech.edu/download/AllDatasetsDownload.tgz


