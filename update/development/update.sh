#!/bin/sh

RELEASE=$1

steps/purge_disk_space.sh             ${RELEASE}

steps/create_directories.pl           ${RELEASE}

steps/mirror_acedb.pl                 ${RELEASE}

steps/mirror_ontology.pl              ${RELEASE}

steps/compile_ontology_resources.pl   ${RELEASE}

steps/create_blast_databases.pl       ${RELEASE}

steps/create_blat_databases.pl        ${RELEASE}

steps/create_epcr_databases.pl        ${RELEASE}

steps/load_genomic_gffdb.pl           ${RELEASE}

steps/load_gff_patches.pl             ${RELEASE}

steps/convert_gff2_to_gff3.pl         ${RELEASE}

steps/load_gmap_gffdb.pl              ${RELEASE}

steps/load_pmap_gffdb.pl              ${RELEASE}

steps/load_clustal_db.pl              ${RELEASE}

steps/dump_features.pl                ${RELEASE}

steps/mirror_annotations.pl           ${RELEASE}

steps/package_databases.pl            ${RELEASE}

steps/update_strains_database.pl      ${RELEASE}

steps/load_autocomplete_db.pl         ${RELEASE}

steps/compile_orthology_resources.pl  ${RELEASE}
