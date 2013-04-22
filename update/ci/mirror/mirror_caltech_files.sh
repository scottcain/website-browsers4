#!/bin/bash

# Mirror expression pattern images from Caltech.

# Run from Jenkins using the Build Periodically option.
#    0 1 1 * *

# Pictures
cd /usr/local/wormbase/website-shared-files/html/img-static/pictures
wget -m -nH --cut-dirs=3 ftp://caltech.wormbase.org/pub/OICR/Pictures

# Movies
cd /usr/local/wormbase/website-shared-files/html/img-static/movies
wget -m -nH --cut-dirs=3 ftp://caltech.wormbase.org/pub/OICR/Movies

# VirtualWorm
cd /usr/local/wormbase/website-shared-files/html/img-static/virtualworm
wget -m -nH --cut-dirs=3 ftp://caltech.wormbase.org/pub/virtualworm/Anatomy_Images

# Grab images from Caltech via rsync over ssh
#HOST=canopus.caltech.edu
#rsync --rsh=ssh -Cav tharris@${HOST}:/usr/local/wormbase/OICR/Pictures/ /usr/local/wormbase/website-shared-files/html/img-static/pictures
#rsync --rsh=ssh -Cav -L tharris@${HOST}:/usr/local/wormbase/OICR/Movies/ /usr/local/wormbase/website-shared-files/html/img-static/movies

#KEY=/home/tharris/.ssh/keys/rsync-user-key 
#rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Pictures/ /usr/local/wormbase/website-shared-files/html/img-static/pictures
#rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Movies/ /usr/local/wormbase/website-shared-files/html/img-static/movies


