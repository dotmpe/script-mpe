#!/bin/sh


catalog_lib_load()
{
  lib_load ck
  # Catalog files found at CWD
  default_env CATALOGS $(setup_tmpf .catalogs)
  # Default catalog file (or relative path) for PWD
  test -n "$CATALOG_DEFAULT" || {
    CATALOG_DEFAULT=$(htd_catalog_name) || CATALOG_DEFAULT=catalog.yaml
  }
  default_env CATALOG "$CATALOG_DEFAULT"
  true
}


htd_catalog_name() # [Dir]
{
  test -z "$1" && dest_dir=. || {
    test -d "$1" || return 2
    fnmatch "*/" "$1" || set -- "$1/"
    dest_dir="$1"
  }
  test -f "$1catalog.yml" && echo "$1catalog.yml"
  test -f "$1catalog.yaml" && echo "$1catalog.yaml"
  true
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

  mtype="$(filemtype "$1")"

  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  { cat <<EOM
- name: '$(basename "$1")'
  mediatype: '$mtype'
  format: '$(file -b "$1")'
  host: $hostname
  keys:
    ck: $(cksum "$1" | cut -d ' ' -f 1,2)
    crc32: $(cksum.py -a rhash-crc32 "$1" | cut -d ' ' -f 1,2)
    md5: $(md5sum "$1" | awk '{print $1}')
    sha1: $(sha1sum "$1" | awk '{print $1}')
    sha2: $(shasum -a 256 "$1" | awk '{print $1}')
    git: $(git hash-object "$1")
EOM
  } >> $CATALOG

  # TODO: see res/ck.py tlit
  #fnmatch "text/*" "$mtype" && { {
  #  echo "    tlit-md5: $(cksum.py -a tlit-md5 --format-from "$mtype" "$1")"
  #  echo "    tlit-sha1: $(cksum.py -a tlit-sha1 --format-from "$mtype" "$1")"
  #  echo "    tlit-sha2: $(cksum.py -a tlit-sha256 --format-from "$mtype" "$1")"
  #} >> $CATALOG ; }

  htd_catalog_file_wherefrom "$1" >> $CATALOG
  htd_catalog_file_birth_date "$1" >> $CATALOG
}

htd_catalog_add() # File..
{
  while test $# -gt 0
  do
    test -n "$1" -a -e "$1" || error "File or dir expected" 1
    test -d "$1" && {
      htd_catalog_add_as_folder "$1" && note "Added folder '$1'" || true
    } || {
      htd_catalog_add_file "$1" && note "Added file '$1'" || true
    }
    shift
  done
}

# Copy record between catalogs (eval record)
htd_catalog_copy_by_name() # CATALOG NAME [ DIR | CATALOG ]
{
  test -n "$1" || set -- $CATALOG "$2" "$3"
  record="$( jsotk yaml2json "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  test -f "$3" && dest_dir="$(dirname "$3")/" || {
    set -- "$1" "$2" "$(htd_catalog_name "$3")" || return
  }

  rotate_file "$3" || return
  jsotk yaml2json $dest | eval jq -c \'. += [ $record ]\' | jsotk json2yaml - > $3
}

# Get path for record, or find it by searching for basename
htd_catalog_record_get_path() # Record [Name]
{
  src_path="$(echo "$1" | jq -r '.path')" || return
  test -n "$src_path" -a "$src_path" != "null" || {
    test -n "$2" || {
      set -- "$1" "$(echo "$1" | jq -r '.name')" || return
    }
    test -n "$2" -a "$2" != "null" || {
        error "No name for record" ; return 1 ; }
    src_path="$(find . -iname "$2")" || return
  }
  test -e "$src_path"
}

# Remove record by name
htd_catalog_drop() # NAME
{
  htd_catalog_drop_by_name "" "$1"
}

# Remove record and src-file by name
htd_catalog_delete() # NAME
{
  htd_catalog_drop_by_name "" "$1"
  htd_catalog_record_get_path "$record" "$1" && {
    rm -v "$src_path" || return
  } || {
    warn "No file to delete, '$1' is already gone"
  }
}

htd_catalog_drop_by_name() # [CATALOG] NAME
{
  test -n "$1" || set -- $CATALOG "$2"

  backup_file "$1" || return
  jsotk yaml2json $1 |
      jq -c ' del( .[] | select(.name=="'"$2"'")) ' |
      sponge | jsotk json2yaml - $1
}

# Copy record and file
htd_catalog_copy() # CATALOG NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3" || return
  htd_catalog_record_get_path "$record" "$2"
  mkdir -v "$(dirname "$dest_dir$src_path")"
  rsync -avzu $src_path $dest_dir$src_path
}

# Transfer record and move file
htd_catalog_move() # [CATALOG] NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3" || return
  htd_catalog_record_get_path "$record" "$2"
  mkdir -v "$(dirname "$dest_dir$src_path")"
  mv -v $src_path $dest_dir$src_path || return
  htd_catalog_drop_by_name "$1" "$2"
}

# Echo src/via URL YAML key-values to append to catalog in raw mode
htd_catalog_file_wherefrom() # Src-File
{
  wherefrom_sh="$(wherefrom "$1" 2>/dev/null)"
  test -z "$wherefrom_sh" || {
    eval $wherefrom_sh
    echo "  source-url: '$url'"
    echo "  via: '$via'"
  }
}

# Echo first-seen YAML key-values to append to catalog in raw mode
htd_catalog_file_birth_date() # Src-File
{
  dob_ts=$(stat -f %B "$1")
  dob=$(date -r $dob_ts +"%Y-%m-%dT%H:%M:%S%z" | sed 's/^\(.*\)\(..\)$/\1:\2/')
  dob_utc=$(TZ=GMT date -r $dob_ts +"%Y-%m-%dT%H:%M:%SZ")
  echo "  first-seen-local: '$dob'"
  echo "  first-seen: '$dob_utc'"
}

# Set one key/string-value pair for one record in catalog
htd_catalog_set() # [Catalog] Entry-Id Key Value [Entry-Key]
{
  test -n "$1" || set -- "$CATALOG" "$2" "$3" "$4" "$5"
  test -n "$2" || error "catalog-set: 2:Entry-ID required" 1
  test -n "$3" || error "catalog-set: 3:Key required" 1
  test -n "$4" || error "catalog-set: 4:Value required" 1
  test -n "$5" || set -- "$1" "$2" "$3" "$4" "name"

  backup_file "$1" || return
  {
    jsotk yaml2json $1 |
      jq -c "map(select(.$5==\""$2"\").$3 |= \"$4\" )" |
      sponge | jsotk json2yaml - $1
  } || { r=$?
    # undo copy
    mv "$dest" "$1"
    return $?
  }
}
