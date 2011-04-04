#!/bin/sh

# This is the original update.sh. It's been badly neglected
# but provides a starting point. 

RELEASE=$1

# Site specific
steps/purge_disk_space.sh             ${RELEASE}

# Perhaps unnecessary if mirroring
steps/create_directories.pl           ${RELEASE}

# For mirrors only
bin/unpack_acedb.pl                   ${RELEASE}           # DONE

# For mirrors only
steps/mirror_ontology.pl              ${RELEASE}

# Retain
steps/compile_ontology_resources.pl   ${RELEASE}

# Retain
steps/compile_orthology_resources.pl  ${RELEASE}

# Migrate
steps/create_blast_databases.pl       ${RELEASE}          # DONE

# Migrate
steps/create_blat_databases.pl        ${RELEASE}          # DONE

# DEPRECATED
#steps/create_epcr_databases.pl        ${RELEASE}

bin/load_genomic_gffdb.pl           ${RELEASE}            # DONE

# Retain? Migrate?
steps/load_gff_patches.pl             ${RELEASE}

# Deprecate this.
steps/convert_gff2_to_gff3.pl         ${RELEASE}

# Migrate / Retain
steps/load_gmap_gffdb.pl              ${RELEASE}

# Migrate / Retain
steps/load_pmap_gffdb.pl              ${RELEASE}

# Retain
steps/load_clustal_db.pl              ${RELEASE}

# Migrate
steps/dump_features.pl                ${RELEASE}

# Retain
steps/mirror_annotations.pl           ${RELEASE}

# Retain
steps/package_databases.pl            ${RELEASE}

# Retain
steps/update_strains_database.pl      ${RELEASE}

# Migrate / Retain
steps/load_autocomplete_db.pl         ${RELEASE}

# Retain
util/build_new_papers_list.pl /usr/local/acedb/elegans