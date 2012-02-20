#!/bin/bash

RELEASE=$1

rm -rf /usr/local/wormbase/acedb/wormbase_${RELEASE}
rm -rf /usr/local/wormbase/databases/${RELEASE}
rm -rf /usr/local/ftp/pub/wormbase/releases/${RELEASE}
rm -rf /usr/local/mysql/data/*${RELEASE}