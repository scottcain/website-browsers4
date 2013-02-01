#!/bin/bash

# Grab images from Caltech via rsync over ssh
KEY=/home/tharris/cron/rsync-user-key 

#rsync --rsh=ssh -Cav /usr/local/wormbase/pictures/virtualworm/ tharris@wb-dev.oicr.on.ca:/usr/local/wormbase/website-shared-files/html/img/virtualworm
#rsync --rsh=ssh -Cav -L /usr/local/wormbase/pictures/ tharris@wb-dev.oicr.on.ca:/usr/local/wormbase/website-shared-files/html/img
rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Pictures/ /usr/local/wormbase/website-shared-files/html/img-static/pictures
rsync -Cav -e "/usr/bin/ssh -i $KEY" -L tharris@canopus.caltech.edu:/usr/local/wormbase/OICR/Movies/ /usr/local/wormbase/website-shared-files/html/img-static/movies