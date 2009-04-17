#!/bin/sh

VERSION=$1

cd /usr/local/wormbase-production
cvs tag ${VERSION}
cvs tag -r ${VERSION} -F current_release
