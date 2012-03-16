#!/bin/bash

export APP=staging
cd /usr/local/wormbase/website/staging
git pull
./script/wormbase-init.sh stop
./script/wormbase-init.sh start