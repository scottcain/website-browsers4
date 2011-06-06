#!/bin/sh

VERSION=$1

cd /usr/local/wormbase/website-classic-staging
cvs tag ${VERSION}
cvs tag -r ${VERSION} -F current_release
