#!/bin/sh


catalog_lib_load()
{
    lib_load ck
}

htd_catalog_find()
{
  htd_catalog_list | while read catalog
  do
    grep -qF "$1" $catalog.yml || continue
    note "Found $1 in $catalog"
  done
}

htd_catalog_ck()
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  ck_read_catalog "$1"
}

htd_catalog_fsck()
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  ck_run_catalogs "$1"
}

htd_catalog_validate()
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  htd_schema_validate "$1" "$scriptpath/schema/catalog.yml"
}

htd_catalog_list()
{
  find -L . -iname 'catalog.y*ml' -not -ipath '*/schema/*' |
      cut -c3- | exts=".yml .yaml" pathnames
}

htd_catalog_add_as_folder()
{
  false
}

htd_catalog_add()
{
  test -n "$1" -a -e "$1" || error "File or dir expected" 1
  test -d "$1" && {
    htd_catalog_add_as_folder "$1" || return
  }

#  magnet:?xt=urn:btih:89aadb0e76eef0b02f9deb53c38aed09fb71768f&dn=Real+Teen+Amateurs+Clips+[2008+Ð³.,+Homevideo,+Amateur,+All+sex]&tr=udp://tracker.leechers-paradise.org:6969&tr=udp://zer0day.ch:1337&tr=udp://open.demon
}
