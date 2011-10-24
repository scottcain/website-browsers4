#!/bin/bash

# Grab images from Caltech once a night via rsync over ssh

#rsync --rsh=ssh -Cav /usr/local/wormbase/pictures/virtualworm/ tharris@wb-dev.oicr.on.ca:/usr/local/wormbase/website-shared-files/html/img/virtualworm
#rsync --rsh=ssh -Cav -L /usr/local/wormbase/pictures/ tharris@wb-dev.oicr.on.ca:/usr/local/wormbase/website-shared-files/html/img
rsync --rsh=ssh -Cav -L tharris@canopus.caltech.edu:/usr/local/wormbase/pictures/ /usr/local/wormbase/website-shared-files/html/img
