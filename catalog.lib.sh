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
  # FIXME linux default_env CATALOG "$CATALOG_DEFAULT"
  test -n "$CATALOG" || export CATALOG="$CATALOG_DEFAULT"
  test -n "$Catalog_Status" || Catalog_Status=.cllct/catalog-status.vars
  test -n "$Catalog_Ignores" || Catalog_Ignores=.cllct/ignores
  test -n "$Catalog_Duplicates" || Catalog_Duplicates=.cllct/duplicates
  test -d .cllct || mkdir .cllct
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

htd_catalog_asjson()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn="$(pathname "$1" .yml .yaml)"
  test -e "$jsonfn" -a "$jsonfn" -nt "$1" || {
    jsotk yaml2json "$1" "$jsonfn"
  }
  cat "$jsonfn"
}

htd_catalog_fromjson()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn="$(pathname "$1" .yml .yaml)"
  jsotk json2yaml "$jsonfn" "$1"
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

htd_catalog_ignores()
{
  ignores_cat global ignore scm
  echo 'catalog.y*ml'
}

htd_catalog_update_ignores()
{
  htd_catalog_ignores > $Catalog_Ignores
}

# List local files for cataloging, excluding dirs but including symlinked
htd_catalog_listdir()
{
  test -n "$1" || set -- "."
  { test -e $Catalog_Ignores && newer_than $Catalog_Ignores $_1DAY
  } || htd_catalog_update_ignores
  globlist_to_regex $Catalog_Ignores >/dev/null
  for lname in $1/*
  do test -f "$lname" || continue ; echo "$lname"
  done | grep -vf $Catalog_Ignores.regex
}

# Like listdir but recurse, uses find
htd_catalog_listtree()
{
  test -n "$1" || set -- "."
  { test -e $Catalog_Ignores && newer_than $Catalog_Ignores $_1DAY
  } || htd_catalog_update_ignores
  local find_ignores="-false $(find_ignores $Catalog_Ignores)"
  eval find $1 $find_ignores -o -print
}

htd_catalog_index()
{
  htd_catalog_listtree "$1" |
      while read fname
      do
          htd_catalog_has_file "$fname" || {
            warn "Missing '$fname'"
            touch "$failed"
          }
      done
}

# TODO: wrap catalog add with some pre/post processing?
htd_catalog_organize()
{
  htd_catalog_listdir "$1" |
      while read fname
      do
          test -f "$fname" || { test -d "$fname" || warn "Not a file '$fname'"
            continue
          }

          matchbox.py check-name "$fname" std-ascii 2>&1 1>/dev/null && {
              true # note "File ok $fname"
              #basename-reg -qq --no-mime-check --num-exts 1 -c "$fname"
          } || {
              ext="$(filenamext "$fname")"
              title="$(basename "$fname" .$ext)"
              newname="$(mkid "$title").$ext"
              note "Title '$title' $newname ($ext)"

          }
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
  test -e $Catalog_Status -a $CATALOG -ot $Catalog_Status || {
    {
        ( htd_catalog_validate "$CATALOG" >/dev/null
        ) && echo schema=0 || echo schema=$?

        ( htd_catalog_index "$CATALOG" >/dev/null
        ) && echo index=0 || echo index=$?

        ( htd_catalog_fsck "$CATALOG" >/dev/null
        ) && echo fsck=0 || echo fsck=$?

    } > $Catalog_Status
    note "Updated status"
  }
}


htd_catalog_status()
{
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
htd_catalog_list_local()
{
  htd_catalog_list_files | tee $CATALOGS | exts=".yml .yaml" pathnames
  test -s "$CATALOGS" || { error "No catalog files found" ; return 1 ; }
}


htd_catalog_has_file() # File
{
  test -n "$CATALOG" || error "CATALOG env expected"
  test -s "$CATALOG" || return 1

  local basename="$(basename "$1" | sed 's/"/\\"/g')"

  grep -q "\\<name:\\ ['\"]\?$(match_grep "$basename")" $CATALOG
}

# Return error state unless every key is found.
htd_catalog_check_keys() # CKS...
{
  while test $# -gt 0
  do
    grep -q "$1" $CATALOG || return
    shift
  done
}

htd_catalog_get_by_name() # [CATALOG] NAME
{
  record="$( htd_catalog_asjson "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  echo $record | jsotk --pretty json2yaml -
}

htd_catalog_get_by_key() # [CATALOG] CKS...
{
  local cat="$1" ; shift ; test -n "$cat" || cat=$CATALOG
  while test $# -gt 0
  do
    record="$( htd_catalog_asjson "$cat" | jq -c ' .[] | select(.keys[]=="'"$1"'")' )" && {
        echo $record | jsotk --pretty json2yaml
        return
    }
    shift
  done
  return 1
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

  local \
      sha1sum=$(sha1sum "$1" | awk '{print $1}')
  htd_catalog_check_keys "$sha1sum" && {
    warn "Keys for '$1' present, matching record:"
    htd_catalog_get_by_key "" "$sha1sum" | tee -a $Catalog_Duplicates
    return 1
  }

  local \
      md5sum=$(md5sum "$1" | awk '{print $1}') \
      sha2sum=$(shasum -a 256 "$1" | awk '{print $1}')
  htd_catalog_check_keys "$md5sum" "$sha2sum" && {
    warn "Keys for '$1' present, matching record:"
    htd_catalog_get_by_key "" "$md5sum" "$sha2sum" | tee -a $Catalog_Duplicates
    return 1
  } || {
    info "New keys for '$1' generated.."
  }

  local mtype="$(filemtype "$1")" \
    basename="$(basename "$1" | sed 's/"/\\"/g')" \
    format="$(fileformat "$1" | sed 's/"/\\"/g')"
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  { cat <<EOM
- name: "$basename"
  mediatype: '$mtype'
  format: '$format'
  tags:
  keys:
    ck: $(cksum "$1" | cut -d ' ' -f 1,2)
    crc32: $(cksum.py -a rhash-crc32 "$1" | cut -d ' ' -f 1,2)
    md5: $md5sum
    sha1: $sha1sum
    sha2: $sha2sum
    git: $(git hash-object "$1")
EOM
    fnmatch "*/*" "$1" && { cat <<EOM
  categories:
  - $(dirname "$1")/
EOM
    } || true
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
      htd_catalog_add_file "$1" &&
        note "Added file '$1'" || true
    }
    shift
  done
}

htd_catalog_add_all()
{
  htd_catalog_add_all_larger -1
}

htd_catalog_add_all_larger() # SIZE
{
  test -n "$1" || set -- 1048576
  htd_catalog_listtree | while read fn
  do
    test -f "$fn" || {
      warn "File expected '$fn'"
      continue
    }
    test $1 -lt $(ht filesize "$fn") || continue
    htd_catalog_add "$fn" || {
      error "Adding '$fn"
      continue
    }
  done
}

# Copy record between catalogs (eval record)
htd_catalog_copy_by_name() # CATALOG NAME [ DIR | CATALOG ]
{
  test -n "$1" || set -- $CATALOG "$2" "$3"
  record="$( htd_catalog_asjson "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  test -f "$3" && dest_dir="$(dirname "$3")/" || {
    set -- "$1" "$2" "$(htd_catalog_name "$3")" || return
  }

  rotate_file "$3" || return
  htd_catalog_asjson "$dest" | eval jq -c \'. += [ $record ]\' | jsotk json2yaml - > $3
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
  htd_catalog_asjson "$1" |
      jq -c ' del( .[] | select(.name=="'"$2"'")) ' |
      htd_catalog_fromjson "$1"
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
  dob_ts=$(filebtime "$1")
  test $dob_ts -ne 0 || dob_ts=$(filemtime "$1")
  # Darwin/BSD
  test "$uname" = "Darwin" && {
    dob=$(date -r $dob_ts +"%Y-%m-%dT%H:%M:%S%z" | sed 's/^\(.*\)\(..\)$/\1:\2/')
    dob_utc=$(TZ=GMT date -r $dob_ts +"%Y-%m-%dT%H:%M:%SZ")
  } || {
    dob=$(date --date="@$dob_ts" +"%Y-%m-%dT%H:%M:%S%z" | sed 's/^\(.*\)\(..\)$/\1:\2/')
    dob_utc=$(TZ=GMT date --date="@$dob_ts" +"%Y-%m-%dT%H:%M:%SZ")
  }
  echo "  first-seen-local: '$dob'"
  echo "  first-seen: '$dob_utc'"
}

# Set one key/string-value pair for one record in catalog
htd_catalog_set_key() # [Catalog] Entry-Id Key Value [Entry-Key]
{
  test -n "$1" || set -- "$CATALOG" "$2" "$3" "$4" "$5"
  test -n "$2" || error "catalog-set: 2:Entry-ID required" 1
  test -n "$3" || error "catalog-set: 3:Key required" 1
  test -n "$4" || error "catalog-set: 4:Value required" 1
  test -n "$5" || set -- "$1" "$2" "$3" "$4" "name"

  trueish "$catalog_backup" && {
    backup_file "$1" || return
  }
  {
    htd_catalog_asjson "$1" | {
        trueish "$json_value" && {
          jq -c "map(select(.$5==\""$2"\").$3 |= $4 )"
        } || {
          jq -c "map(select(.$5==\""$2"\").$3 |= \"$4\" )"
        }
      } | jsotk json2yaml - $1
  } || { r=$?
    # undo copy
    not_trueish "$catalog_backup" || mv "$dest" "$1"
    return $?
  }
}

htd_catalog_update() # [Catalog] Entry-Id Value [Entry-Key]
{
  test -n "$1" || set -- "$CATALOG" "$2" "$3" "$4"
  test -n "$2" || error "catalog-set: 2:Entry-ID required" 1
  test -n "$3" || error "catalog-set: 3:Value required" 1
  test -n "$4" || set -- "$1" "$2" "$3" "name"

  # XXX: sponge not working?
  #trueish "$catalog_backup" && {
    backup_file "$1" || return
  #}
  {
    htd_catalog_asjson "$dest" | {
        jq -c "map(select(.$4==\""$2"\") += $3 )"
    } | jsotk json2yaml - $1

  } || { r=$?
    # undo copy
    #not_trueish "$catalog_backup" ||
    mv "$dest" "$1"
    return $?
  }
}

htd_catalog_annex_import()
{
  annex_list | annex_metadata |
      while read -d $'\f' block
  do
    eval $(echo "$block" | sed 's/^\ *\([^=]*\)=\(.*\)$/\1=\"\2\"/' )
    json="$(echo "$block" | jsotk.py dump -I pkv)"
    note "Importing $name: $json"
    catalog_backup=0 htd_catalog_update "" "$name" "$json"
  done
  return $?

  # JSON directly makes it hard to filter -lastchanged out
  annex_metadata_json
  annex_metadata_json |
      while { read file && read fields ; }
      do
          #htd_catalog_set "" "$file" "$fields"
          echo "file='$file' fields='$fields'"
          #echo "{\"name\":\"$(basename "$file")\",$fields}"
      done
}

# Import files from LFS test-server content dir (by SHA2)
htd_catalog_lfs_import()
{
  lfs_content_list "$1"
}

# TODO: merge all local catalogs (from subtrees to PWD)
htd_catalog_consolidate()
{
  htd_catalog_list_files | while read catalog
  do
    sameas "$CATALOG" "$catalog" && continue
    note "TODO: $catalog"
  done
}

# TODO: separate subtree entries. Go about by moving each file individually
htd_catalog_separate() # PATH
{
  while test $# -gt 0
  do
    htd_catalog_listree "$1" | while read filename
    do
       htd_catalog_move "" "$filename" "$1"
    done
    shift
  done
}

htd_catalog_update()
{
  local fn="$1" ; shift
  local bn="$(basename "$fn" | sed 's/"/\\"/g')" pn="$(find . -iname "$fn" | head -n 1)"
  while test $# -gt 0
  do
    case "$1" in
      mediatype ) htd_catalog_set_key "" "$bn" "mediatype" "$(filemtype "$pn")" ;;
      format ) htd_catalog_set_key "" "$bn" "format" "$(fileformat "$pn")" ;;
      * ) error "unknown update '$1'" 1 ;;
    esac
    shift
  done
}

htd_catalog_update_all()
{
  htd_catalog_listtree | while read fn
  do
    test -f "$fn" || {
      warn "File expected '$fn'"
      continue
    }
    htd_catalog_has_file "$1" || continue

    htd_catalog_update "$fn" "$@" || {
      error "Updating '$fn"
      continue
    }
  done
}
