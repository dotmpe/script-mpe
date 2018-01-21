#!/bin/sh


catalog_lib_load()
{
    lib_load ck
}

htd_catalog_fsck()
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  ck_read_catalog "$1"
}

htd_catalog_validate()
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  htd_schema_validate "$1" "$scriptpath/schema/catalog.yml"
}

htd_catalog_list()
{
  find . -iname 'catalog.y*ml' -not -ipath '*/schema/*' |
      cut -c3- | exts=".yml .yaml" pathnames
}
