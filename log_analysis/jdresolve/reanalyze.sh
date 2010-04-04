#!/bin/bash

ARCHIVE=/usr/local/acedb/wormbase_log_archive/raw
OUT=/usr/local/acedb/wormbase_log_archive/with_hosts

for (( i = 126 ; i <= 165; i++ ))
do
gunzip -c ${ARCHIVE}/access_log.WS${i}.gz | jdresolve -s 16 -l 300000 -r - | gzip -c > ${OUT}/access_log.WS${i}.gz
done


for (( i = 2001 ; i <= 2006; i++ ))
do
gunzip -c ${ARCHIVE}/access_log.${i}.gz | jdresolve -s 16 -l 300000 -r - | gzip -c > ${OUT}/access_log.${i}.gz
done




