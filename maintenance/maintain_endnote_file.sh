#!/bin/sh

DATE=`date +%Y-%m-%d`
OUTPUT=${DATE}-wormbase-literature.endnote
cd /usr/local/ftp/pub/wormbase/misc/literature
wget http://www.textpresso.org/wormbase-literature.endnote --output-document ${OUTPUT}                          
gzip ${OUTPUT}
rm current-wormbase-literature.endnote.gz
ln -s ${OUTPUT}.gz current-wormbase-literature.endnote.gz
