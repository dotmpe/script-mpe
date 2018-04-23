#!/bin/sh


catalog_lib_load()
{
  lib_load ck
  # Catalog files found at CWD
  default_env CATALOGS $(setup_tmpf .catalogs)
  # Default catalog file
  default_env CATALOG catalog.yaml

  test -d .cllct || mkdir .cllct
}


# Look for exact string match in catalog files
htd_catalog_find()
{
  htd_catalog_list_files | while read catalog
  do
    grep -qF "$1" $catalog || continue
    note "Found $1 in $catalog"
  done
}


# Read (echo) checksums from catalog
htd_catalog_ck() # CATALOG
{
  test -n "$1" -a -e "$1" || error "catalog filename arguments expected" 1
  ck_read_catalog "$1"
}


# Run all checksums from catalogs
htd_catalog_fsck()
{
  test -n "$1" || set -- $CATALOG
  ck_run_catalog "$@"
}

# Run all checksums for all catalogs
htd_catalog_fsck_all()
{
  ck_run_catalogs
}


htd_catalog_check()
{
  test -n "$Catalog_Status" || Catalog_Status=.cllct/catalog-status.vars
  test -e $Catalog_Status -a $CATALOG -ot $Catalog_Status || {
    {
        ( htd_catalog_validate "$CATALOG" >/dev/null
        ) && echo schema=0 || echo schema=$?

        ( htd_catalog_fsck "$CATALOG" >/dev/null
        ) && echo fsck=0 || echo fsck=$?

    } > $Catalog_Status
    note "Updated status"
  }
}


htd_catalog_status()
{
  local Catalog_Status=.cllct/catalog-status.vars
  htd_catalog_check

  eval $(cat $Catalog_Status)
  status=$(echo "$schema + $fsck" | bc || return)
  test $status -eq 0 || cat $Catalog_Status
  return $status
}


# Check schema for given catalog
htd_catalog_validate() # CATALOG
{
  test -n "$1" || set -- $CATALOG
  htd_schema_validate "$1" "$scriptpath/schema/catalog.yml"
}


# List local catalog file names
htd_catalog_list_files()
{
  find -L . \( \
      -iname 'catalog.y*ml' -o -iname 'catalog-*.y*ml' \
  \) -not -ipath '*/schema/*' | cut -c3-
}

# Cache catalog pathnames, list basepaths. Error if none found.
htd_catalog_list()
{
  htd_catalog_list_files | tee $CATALOGS | exts=".yml .yaml" pathnames
  test -s "$CATALOGS" || { error "No catalog files found" ; return 1 ; }
}


htd_catalog_has_file() # File
{
  test -n "$CATALOG" || error "CATALOG env expected"
  test -s "$CATALOG" || return 1

  grep -q "\\<name:\\ ['\"]\?$(match_grep "$(basename "$1")")" $CATALOG
}

htd_catalog_add_as_folder()
{
  false # TODO
}

htd_catalog_add_file() # File
{
  htd_catalog_has_file "$1" && {
      warn "File '$(basename "$1")' already in catalog"
      return 1
  }

  { cat <<EOM
- name: '$(basename "$1")'
  keys:
    ck: $(cksum "$1" | cut -d ' ' -f 1,2)
EOM
  } >> $CATALOG

  wherefrom_sh="$(wherefrom "$1" 2>/dev/null)"
  test -z "$wherefrom_sh" || {
    eval $wherefrom_sh
    echo "  source-url: '$url'"
    echo "  via: '$via'"
  } >> $CATALOG

  dob_ts=$(stat -f %B "$1")
  dob=`date -r $dob_ts +"%Y-%m-%dT%H:%M:%S%z" | sed 's/^\(.*\)\(..\)$/\1:\2/'`
  dob_utc=`TZ=GMT date -r $dob_ts +"%Y-%m-%dT%H:%M:%SZ"`
  {
    echo "  mediatype: '$(filemtype "$1")'"
    echo "  format: '$(file -b "$1")'"
	echo "  first-seen-local: $dob"
	echo "  first-seen: $dob_utc"
	test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
	echo "  host: $hostname"
  } >> $CATALOG
}

htd_catalog_add() # File..
{
  while test $# -gt 0
  do
    test -n "$1" -a -e "$1" || error "File or dir expected" 1
    test -d "$1" && {
      htd_catalog_add_as_folder "$1" || true
    } || {
      htd_catalog_add_file "$1" || true
    }
    shift
  done
}

htd_catalog_copy_by_name() # CATALOG NAME [ DIR | CATALOG ]
{
  test -n "$1" || set -- $CATALOG "$2" "$3"
  record="$( jsotk yaml2json "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  test -f "$3" && dest_dir="$(dirname "$3")" || {
    test -d "$3" || return 2
    dest_dir="$3"
    test -f "$3/catalog.yml" && set -- "$1" "$2" "$3/catalog.yml"
    test -f "$3/catalog.yaml" && set -- "$1" "$2" "$3/catalog.yaml"
  }
  fnmatch "*/" "$dest_dir" || dest_dir=$dest_dir/

  mv $3 $3.tmp
  jsotk yaml2json $3.tmp | eval jq -c \'. += [ $record ]\' | jsotk json2yaml - > $3
  rm $3.tmp
}

htd_catalog_copy() # CATALOG NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3"
  src_path="$(echo "$record" | jq -r '.path')"
  dest_path="$dest_dir$src_path"
  rsync -azu $src_path $dest_path
}

htd_catalog_drop_by_name() # [CATALOG] NAME
{
  test -n "$1" || set -- $CATALOG "$2"
  jsotk yaml2json $1 |
      jq -c ' del( .[] | select(.name=="'"$2"'")) ' |
      sponge | jsotk json2yaml - $1
}

htd_catalog_move() # [CATALOG] NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3"
  src_path="$(echo "$record" | jq -r '.path')"
  dest_path="$dest_dir$src_path"
  mv -v $src_path $dest_path
  htd_catalog_drop_by_name "$1" "$2"
}
