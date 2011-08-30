#!/bin/sh

DATE=`date +%Y-%m-%d`
OUTPUT=${DATE}-wormbase-literature.endnote
cd /usr/local/ftp/pub/wormbase/datasets-wormbase/literature
wget http://tazendra.caltech.edu/~postgres/michael/wbpapers.endnote --output-document ${OUTPUT}
gzip ${OUTPUT}
rm current-wormbase-literature.endnote.gz
ln -s ${OUTPUT}.gz current-wormbase-literature.endnote.gz
