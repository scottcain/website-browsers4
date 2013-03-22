#!/bin/sh

BIN=/home/tharris/projects/wormbase/website-admin/util/google_sitemap
${BIN}/dump_urls.pl /usr/local/wormbase/acedb/wormbase
python ${BIN}/sitemap_gen/sitemap_gen.py --config=${BIN}/sitemap_gen/wormbase_config.xml

# Sync to production. This should maybe be its own script to prevent collisions.
#/home/tharris/projects/wormbase/website-admin/update/production/push_software.sh

# Notify Google.
/usr/bin/wget -q www.google.com/webmasters/sitemaps/ping?sitemap=http%3A%2F%2Fwww.wormbase.org%2Fsitemap_index.xml

