#!/bin/bash

# Grab images from Caltech once a night via rsync over ssh

rsync --rsh=ssh -Cav /usr/local/wormbase/pictures/virtualworm/ tharris@wb-dev.oicr.on.ca:/usr/local/wormbase/website-shared-files/html/img/virtualworm
