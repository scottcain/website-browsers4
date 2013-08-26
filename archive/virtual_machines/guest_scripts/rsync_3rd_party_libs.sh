#!/bin/bash

export RSYNC_RSH=ssh

cd /home/wormbase
rsync -Cav todd@brie3.cshl.org:/usr/local/wormbase-lib .
