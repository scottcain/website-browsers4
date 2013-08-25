#!/bin/bash

#ALL_SPECIES=("c_briggsae c_brenneri c_japonica c_remanei c_elegans b_malayi p_pristionchus")
#ALL_SPECIES=("c_remanei c_elegans")
#ALL_SPECIES=("p_pacificus b_malayi")
ALL_SPECIES=("c_elegans")
for SPECIES in ${ALL_SPECIES}
do 
  echo "unpacking ${SPECIES}..."
  gunzip ${SPECIES}.WS200.gff.gz

  echo "converting ${SPECIES} GFF2 to GFF3..."
  ./wormbase_gff2togff3.pl --species ${SPECIES} --gff ${SPECIES}.WS200.gff --output ${SPECIES}.gff3.temp

  echo "Sorting ${SPECIES}..."
  sort -k9,9 ${SPECIES}.gff3.temp | gzip -c > ${SPECIES}.WS200.gff3.gz

  echo "Compressing ${SPECIES}..."
  gzip ${SPECIES}.WS200.gff
done
