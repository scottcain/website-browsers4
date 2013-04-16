#!/bin/bash

# Grab images from Caltech via rsync over ssh
HOST=canopus.caltech.edu
rsync --rsh=ssh -Cav tharris@${HOST}:/usr/local/wormbase/OICR/Pictures/ /usr/local/wormbase/website-shared-files/html/img-static/pictures
rsync --rsh=ssh -Cav -L tharris@${HOST}:/usr/local/wormbase/OICR/Movies/ /usr/local/wormbase/website-shared-files/html/img-static/movies

#KEY=/home/tharris/.ssh/keys/rsync-user-key 
#rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Pictures/ /usr/local/wormbase/website-shared-files/html/img-static/pictures
#rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Movies/ /usr/local/wormbase/website-shared-files/html/img-static/movies


