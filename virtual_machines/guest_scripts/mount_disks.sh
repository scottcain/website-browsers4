#!/bin/bash

# Mount the WormBase core virtual disks

###################################
# Acedb
###################################
cd /usr/local/acedb
mount -t ext3 /dev/sdb1 elegans

###################################
# BLAST / BLAT databases
###################################
cd /usr/local/wormbase
mount -t ext3 /dev/sdc1 databases

###################################
# Autocomplete
###################################
cd /usr/local/mysql/data
mount -t ext3 /dev/sdd1 autocomplete

###################################
# C. elegans GFF
###################################
cd /usr/local/mysql/data
mount -t ext3 /dev/sde1 elegans

###################################
# Other species GFF databases
###################################
cd /usr/local/mysql/data
mount -t ext3 /dev/sdf1 other_species
