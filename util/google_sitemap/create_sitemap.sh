#!/bin/sh

BIN=/usr/local/wormbase/admin/util/google_sitemap
${BIN}/dump_urls.pl /usr/local/wormbase/acedb/wormbase
python ${BIN}/sitemap_gen/sitemap_gen.py --config=${BIN}/sitemap_gen/wormbase_config.xml
/usr/local/bin/wget -q www.google.com/webmasters/sitemaps/ping?sitemap=http%3A%2F%2Fwww.wormbase.org%2Fsitemap_index.xml
