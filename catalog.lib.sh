#!/bin/sh


catalog_lib_load()
{
  lib_load ck
  trueish "$usercat" && {
    test -n "$CATALOGS" || CATALOGS=$HOME/.cllct/catalogs
  } || {
    # Catalog files currently found at CWD
    test -n "$CATALOGS" || CATALOGS=.cllct/catalogs
  }
  # Default catalog file (or relative path) for PWD
  test -n "$CATALOG_DEFAULT" || {
    CATALOG_DEFAULT=$(htd_catalog_name) || CATALOG_DEFAULT=catalog.yaml
  }
  test -n "$CATALOG_IGNORE_DIR" || CATALOG_IGNORE_DIR=.catalog-ignore
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
  test -f "$1catalog.yml" &&
    echo "$1catalog.yml" || {
      test -f "$1catalog.yaml" && echo "$1catalog.yaml" || return
    }
}

htd_catalog_asjson()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn="$(pathname "$1" .yml .yaml).json"
  test -e "$jsonfn" -a "$jsonfn" -nt "$1" || {
    {
      not_falseish "$update_json" || test -e "$jsonfn"
    } && {
      jsotk yaml2json "$1" "$jsonfn"
    }
  }
  cat "$jsonfn"
}

htd_catalog_fromjson()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn="$(pathname "$1" .yml .yaml).json"
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
  {
    ignores_cat global ignore scm
    echo 'catalog.y*ml'
  } | sort -u
}

htd_catalog_update_ignores()
{
  htd_catalog_ignores > "$Catalog_Ignores"
}

# List local files for cataloging, excluding dirs but including symlinked
htd_catalog_listdir()
{
  test -n "$1" || set -- "."
  { test -e "$Catalog_Ignores" && newer_than "$Catalog_Ignores" $_1DAY
  } || htd_catalog_update_ignores
  globlist_to_regex "$Catalog_Ignores" >/dev/null
  for lname in "$1"/*
  do test -f "$lname" || continue ; echo "$lname"
  done | grep -vf "$Catalog_Ignores.regex"
}

# List untracked files, from SCM if present, or uses find with ignores.
# Set use_find=1 to override for present SCM, or scm_all/scm_x
htd_catalog_listtree()
{
  test -n "$1" || set -- "."
  local scm='' ; trueish "$use_find" || vc_getscm "$1"
  { test -n "$scm" && {
    info "SCM: $scm"
    req_cons_scm
    # XXX: { vc tracked-files || error "Listing all from SCM" 1; } ||
    trueish "$scm_all" && {
      { vc ufx || error "Listing with from SCM" 1; } ; } ||
      { vc uf || error "Listing from SCM" 1; };
  } || {
    trueish "$use_find" &&
      info "Override SCM, tracking files directly ($Catalog_Ignores)" ||
      info "No SCM, tracking files directly ($Catalog_Ignores)"
    { test -e "$Catalog_Ignores" && newer_than "$Catalog_Ignores" $_1DAY
    } || htd_catalog_update_ignores
    local find_ignores="-false $(find_ignores "$Catalog_Ignores") "\
" -o -exec test ! \"{}\" = \"$1\" -a -e \"{}/$CATALOG_DEFAULT\" ';' -a -prune "\
" -o -exec test -e \"{}/$CATALOG_IGNORE_DIR\" ';' -a -prune"
    #eval find "$1" -not -type d $find_ignores -o -type f -a -print
    eval find "$1" $find_ignores -o -type f -a -print ;
  } }
}

# List tree, and check entries exists for each file-name
htd_catalog_index()
{
  htd_catalog_listtree "$1" |
      while read fname
      do
          test -f "$fname" || { warn "File expected '$fname'" ; continue ; }
          htd_catalog_has_file "$fname" || {
            warn "Missing '$fname'"
            echo "$fname" >>"$failed"
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


# Update status (validate doc, set full=1 to check filetree index and checksums)
htd_catalog_check()
{
  test -e $Catalog_Status -a $CATALOG -ot $Catalog_Status || {
    {
        ( htd_catalog_validate "$CATALOG" >/dev/null
        ) && echo schema=0 || echo schema=$?

        ( htd_catalog_index "$CATALOG" >/dev/null
        ) && echo index=0 || echo index=$?

        trueish "$full" || return 0

        ( htd_catalog_fsck "$CATALOG" >/dev/null
        ) && echo fsck=0 || echo fsck=$?

    } > $Catalog_Status
    note "Updated status"
  }
}

# Process htd-catalog-check results
req_catalog_status()
{
  eval $(cat $Catalog_Status)
  status=$(echo "$schema + $fsck" | bc) || return -1
  test $status -eq 0 || cat $Catalog_Status
  return $status
}


# Get status for catalog and directory, normally validate + check index
# Set full to fsck subsequently.
htd_catalog_status()
{
  htd_catalog_check
  req_catalog_status
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
  htd_catalog_list_files | tee .cllct/catalogs
  # | exts=".yml .yaml" pathnames
  test -s ".cllct/catalogs" || { error "No catalog files found" ; return 1 ; }
}

# Update user catalog list (from locatedb)
htd_catalog_list_global()
{
  # XXX: no brace-expansion for locate '*/catalog{,-*}.y{,a}ml'
  locate '*/catalog.yaml' '*/catalog.yml' \
    '*/catalog-*.yml' '*/catalog-*.yaml' | tee ~/.cllct/catalogs
  #| exts=".yml .yaml" pathnames
  test -s ~/.cllct/catalogs || { error "No catalog files found" ; return 1 ; }
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

htd_catalog_add_from_folder()
{
  htd_catalog_add_all_larger "$1" -1
}

htd_catalog_add_file() # File
{
  htd_catalog_has_file "$1" && {
    info "File '$(basename "$1")' already in catalog"
    return 2
  }

  local \
      sha1sum=$(sha1sum "$1" | awk '{print $1}')
  htd_catalog_check_keys "$sha1sum" && {
    echo "add-file: $1" >>$Catalog_Duplicates
    warn "Keys for '$1' present, matching record:"
    # NOTE: don't update JSON while check-keys doesn't either
    update_json=false \
    htd_catalog_get_by_key "" "$sha1sum" | tee -a $Catalog_Duplicates
    return 1
  }

  local \
      md5sum=$(md5sum "$1" | awk '{print $1}') \
      sha2sum=$(shasum -a 256 "$1" | awk '{print $1}')
  htd_catalog_check_keys "$md5sum" "$sha2sum" && {
    echo "add-file: $1" >>$Catalog_Duplicates
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
EOM
    # git: $(git hash-object "$1")
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
      #htd_catalog_add_as_folder "$1" && note "Added folder '$1'" || true
      htd_catalog_add_from_folder "$1" && note "Added folder '$1'" || true
    } || {
      htd_catalog_add_file "$1" && note "Added file '$1'" || { r=$?
        test $r -eq 2 && continue
        error "Adding '$1' ($r)"
      }
    }
    shift
  done
}

htd_catalog_add_all()
{
  htd_catalog_add_all_larger "." -1
}

htd_catalog_add_all_larger() # DIR SIZE
{
  test -n "$1" || set -- . "$2"
  test -n "$2" || set -- "$1" 1048576
  htd_catalog_listtree "$1" | while read fn
  do
    test -f "$fn" || { warn "File expected '$fn'" ; continue ; }
    test $2 -lt $(ht filesize "$fn") || continue
    htd_catalog_add_file "$fn" || { r=$?
      test $r -eq 2 && continue
      error "Adding '$fn' ($r)"
    }
  done
}

htd_catalog_untracked()
{
  htd_catalog_listtree "$1" | while read fn
  do
    test -f "$fn" || continue
    htd_catalog_has_file "$fn" && continue
    echo "$fn"
  done
}

# Copy record between catalogs (eval record)
htd_catalog_copy_by_name() # CATALOG NAME [ DIR | CATALOG ]
{
  test -n "$1" || set -- $CATALOG "$2" "$3"
  record="$( htd_catalog_asjson "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  test -f "$3" || {
    test -d "$3" && {
      set -- "$1" "$2" "$(htd_catalog_name "$3" || echo $CATALOG_DEFAULT)"
    }
  }
  dest_dir="$(dirname "$3")/"

  test -s "$3" || echo "[]" > $3
  rotate_file "$3"
  htd_catalog_asjson "$3" | eval jq -c \'. += [ $record ]\' | jsotk json2yaml - > $3
}

# Get path for record, or find it by searching for basename
htd_catalog_record_get_path() # Record [Name]
{
  src_path="$(echo "$1" | jq -r '.path')"
  test -n "$src_path" -a "$src_path" != "null" || {
    test -n "$2" || {
      set -- "$1" "$(echo "$1" | jq -r '.name')" || {
        error "No name given or path or name in record"
        return 1
      }
    }
    test -n "$2" -a "$2" != "null" || {
        error "No name for record" ; return 1 ; }
    iname="$(echo "$2" | sed 's/[][?\*]/\\&/g')"
    export src_path="$(find . -iname "$iname")" || return
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
  test -s "$1" && backup_file "$1" || echo "[]" > $1
  htd_catalog_asjson "$1" |
      jq -c ' del( .[] | select(.name=="'"$2"'")) ' |
      jsotk json2yaml --pretty - "$1"
}

# Copy record and file
htd_catalog_copy() # CATALOG NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3" || return
  htd_catalog_record_get_path "$record" "$2" || error "Lookup up file '$2'" 1
  test -e "$src_path" || error "Can't find file '$2'" 1
  mkdir -v "$(dirname "$dest_dir$src_path")" || return
  rsync -avzu "$src_path" "$dest_dir$src_path"
}

# Transfer record and move file
htd_catalog_move() # [CATALOG] NAME [ DIR | CATALOG ]
{
  htd_catalog_copy_by_name "$1" "$2" "$3" || return
  htd_catalog_record_get_path "$record" "$2" || error "Lookup up file '$2'" 1
  test -e "$src_path" || error "Can't find file '$2'" 1
  mkdir -vp "$(dirname "$dest_dir$src_path")" || return
  mv -v "$src_path" "$dest_dir$src_path" || return
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

  #trueish "$catalog_backup" && {
    backup_file "$1" || return
  #}
  {
    htd_catalog_asjson "$1" | {
        trueish "$json_value" && {
          jq -c "map(select(.$5==\""$2"\").$3 |= $4 )" || return

        } || {
          jq -c "map(select(.$5==\""$2"\").$3 |= \"$4\" )" || return

        }
      } | jsotk json2yaml - $1
  } || { r=$?
    # undo copy
    #not_trueish "$catalog_backup" ||
    mv "$dest" "$1"
    return $?
  }
}

htd_catalog_update() # [Catalog] Entry-Id Value [Entry-Key]
{
  test -n "$1" || set -- "$CATALOG" "$2" "$3" "$4"
  test -n "$2" || error "catalog-set: 2:Entry-ID required" 1
  test -n "$3" || error "catalog-set: 3:Value required" 1
  test -n "$4" || set -- "$1" "$2" "$3" "name"

  #trueish "$catalog_backup" && {
    backup_file "$1" || return
  #}
  {
    htd_catalog_asjson "$1" | {
        jq -c "map(select(.$4==\""$2"\") += $3 )"
    } | jsotk json2yaml - $1

  } || { r=$?
    # undo copy
    #not_trueish "$catalog_backup" ||
    mv "$dest" "$1"
    return $?
  }
}

# Import entries from Annex. Even if a file does not exist, this can take
# keys, tags and other metadata from GIT annex.
htd_catalog_annex_import()
{
  annex_list | key_metadata=1 annex_metadata | while read -d $'\f' block_
  do
    block="$(echo "$block_" | sed 's/=\(.*[^0-9].*\)\ *$/="\1"/g' )"
    json="$(echo "$block" | jsotk.py dump -I pkv)"
    note "Importing $json"
    catalog_backup=0 htd_catalog_update "" "$name" "$json"
  done
  return $?

  # XXX: JSON directly makes it hard to filter -lastchanged out
  annex_metadata_json |
      while { read file && read fields ; }
      do
          #htd_catalog_set "" "$file" "$fields"
          echo "file='$file' fields='$fields'"
          #echo "{\"name\":\"$(basename "$file")\",$fields}"
      done
}

# TODO: Import files from LFS test-server content dir (by SHA2)
htd_catalog_lfs_import()
{
  lfs_content_list "$1"
}

# TODO: import all checksum table files
htd_catalog_ck_import()
{
  catalog.py --catalog="$CATALOG" importcks "$@"
}

req_cons_scm()
{
  test -n "$scm_all" || {
    # TODO prompt "Scan untracked only, or all (SCM untracked and excluded files)?"
    scm_all=0
  }
}

# TODO: Consolidate any file; list files and check for index.
# See htd-catalog-listtree to control which files to check
htd_catalog_consolidate()
{
  test -n "$1" || set -- "."
  htd_catalog_listtree | while read fpath
  do
    case "$fpath" in

      *.md5|*.md5sum ) ;;
      *.sha1|*.sha1sum ) ;;

      *.meta ) ;;
      catalog.y*ml|*/catalog.y*ml ) ;;

      * )
          note "Scanning for unknown file '$fpath'..."
          htd_catalog_scan_for "$fpath"
        ;;

    esac
  done
}
htd_catalog_cons() { htd_catalog_consolidate "$@"; }

# TODO: consolidate data from metafiles
htd_catalog_consolidate_metafiles()
{
  find ./ -iname '*.meta' | while read metafile
  do
    htd_catalog_add_file "$metafile"
  done
  #find ./ \( -iname '*.sha1*' -o -iname '*.md5*' \)
}

# TODO: merge all local catalogs (from subtrees to PWD)
htd_catalog_consolidate_catalogs()
{
  htd_catalog_list_files | while read catalog
  do
    sameas "$CATALOG" "$catalog" && continue
    note "TODO: $catalog"
  done
}

# Requires local or global catalogs list
htd_catalog_scan_for()
{
  # Use quickest checksum and start for global lookup
  htd_catalog_scan_for_md5 "$1" && return

  # Can also include some Annex backends and LFS
  htd_catalog_scan_for_sha2 "$1" && return

  #htd_catalog_scan_for_sha1 "$1" && return
}

htd_catalog_scan_for_md5()
{
  info "Scanning catalogs for MD5 of $1..."
  test_exists "$1"
  local md5sum=$(md5sum "$1" | awk '{print $1}')
  note "Looking for MD5: $md5sum..."
  while read catalog
  do
    grep -q 'md5:\ '"$md5sum" $catalog || continue
    echo "$catalog"
    return
  done < "$CATALOGS"
  return 1
}

htd_catalog_scan_for_sha2()
{
  test_exists "$1"
  local sha2sum=$(shasum -a 256 "$1" | awk '{print $1}')
  note "Looking for SHA2: $sha2sum..."
  while read catalog
  do
    grep -q 'sha2:\ '"$sha2sum" $catalog || continue
    echo "$catalog"
    return
  done < "$CATALOGS"

  note "Looking in Annex backends..."
  for annex in /srv/annex-*/*/
  do
    test -d "$annex/.git/annex/objects" || continue
    info "Searching '$annex' Annex..."

    find "$annex/.git/annex/objects" -type d \
      -iname 'SHA256E-s*--'"$sha2sum"'.*' -print -quit |
      while read obj
      do
        test -n "$obj" -a -d "$obj" || continue
        echo "$annex"
        return
      done

    # Somehow this locks up on 11.3 archive-old
    #key=".git/annex/objects/*/*/SHA256E-s*--$sha2sum.*"
    #for x in $annex$key
    #do
    #  test -e "$x" || continue
    #  echo "$annex"
    #  return
    #done
  done

  return 1
}


# Separate subtree entries. Go about by moving each file individually
htd_catalog_separate() # PATH
{
  test -d "$1" || error "dir expected" 1
  while test $# -gt 0
  do
    htd_catalog_listtree "$1" | while read filename
    do
       htd_catalog_move "" "$filename" "$1"
    done
    shift
  done
}

htd_catalog_update()
{
  test -n "$1" || error "expected properties to update" 1
  local fn="$1" ; shift
  local bn="$(basename "$fn" | sed 's/"/\\"/g')" pn="$(find . -iname "$fn" | head -n 1)"
  test -e "$pn" || error "No file '$pn'" 1
  while test $# -gt 0
  do
    case "$1" in
      mediatype ) htd_catalog_set_key "" "$bn" "mediatype" "$(filemtype "$pn")" ;;
      format )
        echo htd_catalog_set_key "" "$bn" "format" "$(fileformat "$pn")"
        htd_catalog_set_key "" "$bn" "format" "$(fileformat "$pn")" ;;
      * ) error "unknown update '$1'" 1 ;;
    esac
    shift
  done
}

htd_catalog_update_all()
{
  test -n "$1" || error "expected properties to update" 1
  htd_catalog_listtree | while read fn
  do
    test -f "$fn" || continue
    htd_catalog_has_file "$1" || continue
    htd_catalog_update "$fn" "$@" || {
      error "Updating '$fn"
      continue
    }
  done
}

htd_catalog_add_empty_file()
{
  test -n "$1" || set -- "$CATALOG"
  htd_catalog_get_by_key "$1" \
    $empty_sha2 && {
      warn "Existing record found" 1
    }

  test -f "$1" || {
    test -d "$1" && {
      set -- "$(htd_catalog_name "$1" || echo $CATALOG_DEFAULT)"
    }
  }
  { cat <<EOM
- name: .empty
  format: empty
  mediatype: inode/x-empty; charset=binary
  keys:
    ck: 4294967295 0
    crc32: 0 0
    md5: d41d8cd98f00b204e9800998ecf8427e
    sha1: da39a3ee5e6b4b0d3255bfef95601890afd80709
    sha2: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    git: e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
EOM
  } >> "$1"
}

#htd_catalog_dedupe() # DIR|GLOB|-
#{
#  htd_catalog_untracked | while read fn
#  do
#
#
#  local \
#      sha1sum=$(sha1sum "$1" | awk '{print $1}')
#  htd_catalog_check_keys "$sha1sum" && {
#    echo "add-file: $1" >>$Catalog_Duplicates
#    warn "Keys for '$1' present, matching record:"
#    # NOTE: don't update JSON while check-keys doesn't either
#    update_json=false \
#    htd_catalog_get_by_key "" "$sha1sum" | tee -a $Catalog_Duplicates
#    return 1
#  }
#  done
#}
