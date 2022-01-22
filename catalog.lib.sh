#!/bin/sh

# Catalog: maintain card records for files with Id and meta info

catalog_lib_load()
{
  lib_load ck-htd ck || return

  # Existing or default catalog file (relative path) for PWD
  test -n "${CATALOG_DEFAULT-}" || {
    CATALOG_DEFAULT=$(htd_catalog__name) || CATALOG_DEFAULT=catalog.yaml
  }
  test -n "${CATALOG_IGNORE_DIR-}" || CATALOG_IGNORE_DIR=.catalog-ignore
  test -n "${CATALOG-}" || CATALOG="$CATALOG_DEFAULT"

  # List for all catalogs (global) or below PWD (default)
  test -n "${CATALOGS-}" || CATALOGS=.cllct/catalogs.list
  test -n "${GLOBAL_CATALOGS-}" ||
      GLOBAL_CATALOGS=$HOME/$(pathname $CATALOGS .list)-global.list

  test -n "${Catalog_Status-}" || Catalog_Status=.cllct/catalog-status.vars
  test -n "${Catalog_Ignores-}" || Catalog_Ignores=.cllct/ignores
  test -n "${Catalog_Duplicates-}" || Catalog_Duplicates=.cllct/duplicates

  test -n "${ANNEX_DIR-}" || {
    ANNEX_DIR="/srv/annex-local"
    test ! -h "$ANNEX_DIR" || ANNEX_DIR="/srv/$(readlink /srv/annex-local)"
  }
}

catalog_lib_init()
{
  test "${catalog_lib_init-}" = "0" && return
  test -d .cllct || mkdir .cllct
  true "${define_all:=1}" # XXX: override htd-load to set any argv opts to vars
}

htd_catalog__info() # Some catalog info ~
{
  $LOG header $scriptname:catalog:info

  $LOG header2 "Catalog-Default" "$CATALOG_DEFAULT"
  $LOG header2 "Catalog" "$CATALOG" "$(echo $( filesize "$CATALOG" && {
      count_lines "$CATALOG"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "Catalogs" "$CATALOGS" "$(echo $( filesize "$CATALOGS" && {
      count_lines "$CATALOGS"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "Global-Catalogs" "$GLOBAL_CATALOGS" "$(echo $(
    filesize "$GLOBAL_CATALOGS" && {
        count_lines "$GLOBAL_CATALOGS"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "global" "$global"
}

htd_catalog__paths() # List catalog path-names ~
{
  trueish "$global" && {
    htd_catalog__req_global
    return $?
  } || {
    htd_catalog__req_local
  }
}

htd_catalog__name() # Look for Catalog-Default ~ [Dir]
{
  test $# -gt 0 || set -- ./
  test $# -eq 1 -a -d "$1" || return 97

  fnmatch "*/" "$1" || set -- "$1/"

  true "${CATALOG_DEFAULT:="catalog.yml"}"
  test -f "$1$CATALOG_DEFAULT" &&
    echo "$1$CATALOG_DEFAULT" || {

      test -f "$1$(pathname $CATALOG_DEFAULT .yml).yaml" &&
        echo "$1$(pathname $CATALOG_DEFAULT .yml).yaml" || return
    }
}

htd_catalog__as_json()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn= s=
  jsonfn="$(pathname "$1" .yml .yaml).json"
  { test -e "$jsonfn" -a "$jsonfn" -nt "$1" || {
        {
          trueish "${update_json-}" || test ! -e "$jsonfn"
        } && {
          jsotk yaml2json --ignore-alias "$1" "$jsonfn" || s=$?
          test ${s:-0} -eq 0 ||
            error "Generating <$jsonfn>" $s
        } ||
          alert "Updated needed from YAML <$jsonfn>" 1
      }
    } >&2
  test -e "$jsonfn" || error "Unable to get CATALOG json for '$1' '$jsonfn'" 1
  cat "$jsonfn"
}

htd_catalog__from_json()
{
  test -n "$1" || set -- "$CATALOG"
  local jsonfn="$(pathname "$1" .yml .yaml).json"
  jsotk json2yaml --ignore-alias "$jsonfn" "$1"
}


# Look for exact string match in catalog files
htd_catalog__find() # Str
{
  htd_catalog__req_local | while read catalog; do
    grep -qF "$1" "$catalog" || continue
    note "Found '$1' in $catalog"
  done
}

htd_catalog__ignores()
{
  {
    ignores_cat global ignore scm
  } | sort -u
}

htd_catalog__update_ignores()
{
  htd_catalog__ignores > "$Catalog_Ignores"
}

# List local files for cataloging, excluding dirs but including symlinked
catalog_listdir()
{
  test -n "$1" || set -- "."
  { test -e "$Catalog_Ignores" && newer_than "$Catalog_Ignores" $_1DAY
  } || htd_catalog__update_ignores
  globlist_to_regex "$Catalog_Ignores" >/dev/null
  for lname in "$1"/*
  do test -f "$lname" || continue ; echo "$lname"
  done | grep -vf "$Catalog_Ignores.regex"
}

# List untracked files for SCM dir, else find everything with ignores. Assuming
# SCM can handle its own status.
# Set use_find=1 to override for present SCM; scm_all to list SCM excluded as
# well.
htd_catalog__listtree() # List untracked or find all unignored ~ Path
{
  test -n "$1" || set -- "."
  local scm='' ; test ${use_find:-0} -eq 1 || vc_getscm "$1"
  { test -n "$scm" && {
    std_info "SCM: $scm (listing untracked/ignored only)"
    req_cons_scm
    # XXX: { vc.sh tracked-files || error "Listing all from SCM" 1; } ||
    trueish "$scm_all" && {
      { vc.sh ufx || error "Listing with from SCM" 1; } ; } ||
      { vc.sh uf || error "Listing from SCM" 1; };
  } || {
    test ${use_find:-0} -eq 1 &&
      std_info "Override SCM, tracking files directly ($Catalog_Ignores)" ||
      std_info "No SCM, tracking files directly ($Catalog_Ignores)"
    { test -e "$Catalog_Ignores" && newer_than "$Catalog_Ignores" $_1DAY
    } || htd_catalog__update_ignores
    local find_ignores="-false $(ignores_find "$Catalog_Ignores") "\
" -o -exec test ! \"{}\" = \"$1\" -a -e \"{}/$CATALOG_DEFAULT\" ';' -a -prune "\
" -o -exec test -e \"{}/$CATALOG_IGNORE_DIR\" ';' -a -prune "\
" -o -exec test ! -d \"{}\" ';' "
    #eval find "$1" -not -type d $find_ignores -o -type f -a -print
    eval find -H "$1" $find_ignores -a -print ;
  } }
}

# List tree, and check entries exists for each file-name
htd_catalog__index() # Check each listtree fname ~ Path
{
  htd_catalog__listtree "$1" | while read fname
    do
      test -f "$fname" || {
        test -d "$fname" && {
          trueish "$recursive" || {
            warn "Skipping dir '$fname'" ; continue ; }
          htd_catalog__index "$fname"
        }
        warn "File expected '$fname'" ; continue ; }

      htd_catalog__has_file "$fname" || {
        $LOG warn "$PWD" "Missing" "$fname"
        echo "$fname" >>"$failed"
      }
    done
}

# List dir, check file extension-mime map and ...
# TODO: wrap catalog add with some pre/post processing?
htd_catalog__organize() # ~ Path
{
  local r=

  test -n "$dry_run" || {
      test -z "$noact" && dry_run=0 || dry_run=$noact
    }
  test -n "$keep_going" || keep_going=1

  htd_catalog__listdir "$1" |
    while read fname
    do
      test -f "$fname" || {
        test -d "$fname" || warn "Not a file '$fname'"
        continue
      }

      # TODO: matchbox.py check-name "$fname" std-ascii  && {

      mime=$(basename-reg -o mime --no-mime-check --num-exts 1 -c "$fname") || {

        $LOG error "mime" "No mime for extension" "$fname" 1
        trueish "$keep_going" && { r=1; continue; }
        return $?
      }
      ext="$(filenamext "$fname")"
      title="$(basename "$fname" .$ext)"
      newname="$(mkid "$title" "" "").$ext"

      htd_catalog__has_file "$fname" && {
        note "File OK '$title' $mime $newname ($ext)"
        continue

      } || {

        # Look for local sync rules, reprocess if required
        note "New file Title '$title' $mime $newname ($ext)"

        # TODO: find nearest package, look for sync-directives
        # TODO: ht-copy-* :!

      }
    done
  return $r
}

# Read (echo) checksums from catalog
htd_catalog__ck () # ~ CATALOG
{
  test -n "${1-}" || set -- $CATALOG
  ck_read_catalog "$1"
}

# Run all checksums from catalog (recalc from file and compare)
htd_catalog__fsck () # ~ CATALOG
{
  test -n "${1-}" || set -- $CATALOG
  ck_run_catalog "$@"
}

# Run all checksums for all catalogs
htd_catalog__fsck_all ()
{
  ck_run_catalogs
}

# Update status (validate doc, set --full=1 to check filetree index and checksums)
htd_catalog__check()
{
  # Clean empty status-file
  test ! -e "$Catalog_Status" -o -s "$Catalog_Status" || rm "$Catalog_Status"

  # Renew status-file if older than catalog
  test -e $Catalog_Status -a $CATALOG -ot $Catalog_Status || {
    {
        ( htd_catalog__validate "$CATALOG" >/dev/null
        ) && echo schema=0 || echo schema=$?

        ( htd_catalog__index "$CATALOG" >/dev/null
        ) && echo index=0 || echo index=$?

        test ${choice_full:-0} -eq 1 && {

          ( htd_catalog__fsck "$CATALOG" >/dev/null
          ) && echo fsck=0 || echo fsck=$?
        } || true

    } > $Catalog_Status

    $LOG note "$scriptname:catalog:check" "Updated status"
  }
}

# Process htd-catalog-check results
req_catalog_status()
{
  status=$(echo $(cut -d'=' -f2 $Catalog_Status|tr '\n' ' ')|tr ' ' '+'|bc ) ||
      return
  test -n "$status" || {
    $LOG error ":catalog:status" "No status bits" "$(ls -la $Catalog_Status)"
    return 51 # No status found for catalog
  }
  test $status -eq 0 && {
    $LOG note "Pass" "status:" "$(lines_to_words $Catalog_Status)"
  } || {
    $LOG warn "Failed" "status:" "$(lines_to_words $Catalog_Status)"
  }
  return $status
}


# Get status for catalog and directory, normally validate + check index.
# Set full to fsck subsequently.
htd_catalog__status()
{
  test ${choice_global:-0} -eq 1 && {

    htd_catalog__req_global | sed 's/\.ya\?ml$//' | while read catalog; do
        #htd_catalog__check || return
        #req_catalog_status

      (
        cd $(dirname $catalog) || continue
        CATALOG="$(basename $catalog)"

        ( htd_catalog__validate "$CATALOG" )

      )
        #( htd_catalog__index "$CATALOG" )
    done
    return $?

  } || {

    htd_catalog__check || return
    req_catalog_status
  }
}


# Check schema for given catalog
htd_catalog__validate() # CATALOG
{
  test -n "$1" || set -- $CATALOG
  htd_schema_validate "$1" "$scriptpath/schema/catalog.yml"
}


# List local catalog file names
htd_catalog__list_files()
{
  find -L . \( \
      -iname 'catalog.y*ml' -o -iname 'catalog-*.y*ml' \
  \) -not -ipath '*/schema/*' | cut -c3-
}


# Set fn env var to full path for name
set_cataloged_file()
{
  test -e "$1" && fn="$1" || fn="$(find . -iname "$1")"
  test -e "$fn" -o -h "$fn" || {
    test -n "$fn" && {
      warn "Expected one file path: '$fn'" ; return 1
    } || {
      warn "Expected one file path, found nothing for '$1'" ; return 1
    }
  }
  # TODO: trueish "$strict" require catalog entry
}


# Cache catalogs, list basepaths. Error if none found.
htd_catalog__list_local()
{
  { htd_catalog__list_files || return
  } | tee "$CATALOGS" || return
  test -s "$CATALOGS" || { error "No catalog files found" ; return 1 ; }
}

htd_catalog__req_local()
{
  test -e $CATALOGS && {
    cat $CATALOGS
    $LOG "info" "$scriptname:catalog:req-local" "To update list run:" 'catalog list-local'
  } || {
    htd_catalog__list_local || return
  }
}

# Update user catalog list (from locatedb)
htd_catalog__list_global()
{
  # NOTE: no brace-expansion here (locate '*/catalog{,-*}.y{,a}ml')
  { locate '*/catalog.yaml' '*/catalog.yml' \
    '*/catalog-*.yml' '*/catalog-*.yaml' || return
  } | tee ~/$CATALOGS || return
  test -s ~/$CATALOGS || { error "No catalog files found" ; return 1 ; }
}

htd_catalog__req_global()
{
  test -e $GLOBAL_CATALOGS && {
    cat $GLOBAL_CATALOGS
    $LOG "info" "$scriptname:catalog:req-global" "To update list run:" 'catalog list-global'
  } || {
    htd_catalog__list_global || return
  }
}

htd_catalog__list() # List catalog names
{
  { trueish "$global" && {
      htd_catalog__req_global || return
    } || {
      htd_catalog__req_local || return
    } | sed 's/\.ya\?ml$//'; }
}

htd_catalog__has_file() # File
{
  test -n "$CATALOG" || error "CATALOG env expected"
  test -s "$CATALOG" || return 1

  local basename="$(basename "$1" | sed 's/"/\\"/g')"
  grep -q "^[-]\?  *\\<name:\\ ['\"]\?$(match_grep "$basename")" $CATALOG
}


# Return error state unless every key is found.
htd_catalog__check_keys() # CKS...
{
  while test $# -gt 0
  do
    grep -q "$1" $CATALOG || return
    shift
  done
}

htd_catalog__get_by_name() # [CATALOG] NAME
{
  record="$( htd_catalog__as_json "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  echo $record | jsotk --pretty json2yaml -
}

htd_catalog__get_by_key() # [CATALOG] CKS...
{
  local cat="$1" ; shift ; test -n "$cat" || cat=$CATALOG
  while test $# -gt 0
  do
    record="$( htd_catalog__as_json "$cat" | jq -c ' .[] | select(.keys[]=="'"$1"'")' )" && {
        echo $record | jsotk --pretty json2yaml
        return
    }
    shift
  done
  return 1
}

htd_catalog__add_file() # File
{
  # TODO: check other catalogs, dropped entries too before adding.
  htd_catalog__has_file "$1" && {
    # std_info "File '$(basename "$1")' already in catalog"
    $LOG note "" "already in catalog" "$1"
    return 2
  }

  local \
      sha1sum=$(sha1sum "$1" | awk '{print $1}')
  htd_catalog__check_keys "$sha1sum" && {
    echo "add-file: $1" >>$Catalog_Duplicates
    warn "Keys for '$1' present, matching record:"
    # NOTE: don't update JSON while check-keys doesn't either
    update_json=false \
    htd_catalog__get_by_key "" "$sha1sum" | tee -a $Catalog_Duplicates
    return 1
  }

  local \
      md5sum=$(md5sum "$1" | awk '{print $1}') \
      sha2sum=$(shasum -a 256 "$1" | awk '{print $1}')
  htd_catalog__check_keys "$md5sum" "$sha2sum" && {
    echo "add-file: $1" >>$Catalog_Duplicates
    warn "Keys for '$1' present, matching record:"
    htd_catalog__get_by_key "" "$md5sum" "$sha2sum" | tee -a $Catalog_Duplicates
    return 1
  } || {
    std_info "New keys for '$1' generated.."
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

  htd_catalog__file_wherefrom "$1" >> $CATALOG
  htd_catalog__file_birth_date "$1" >> $CATALOG
}

# Add entries for given paths
# Attn: records only the basename so duplicate basenames (from any directory)
# will not be added, only the first occurence.
htd_catalog__add() # File..
{
  while test $# -gt 0
  do
    test -n "$1" -a -e "$1" || error "File or dir expected" 1
    test -d "$1" && {
      #htd_catalog__add_as_folder "$1" && note "Added folder '$1'" || true
      htd_catalog__add_from_folder "$1" &&
        note "Added folder '$1'" || error "Adding folder '$1'" 1
    } || {
      htd_catalog__add_file "$1" && note "Added file '$1'" || { r=$?
        test $r -eq 2 || error "Adding '$1' ($r)"
      }
    }
    shift
  done
}

# Add all untracked files (if default; use_find=0)
htd_catalog__add_all()
{
  htd_catalog__add_all_larger "." -1
}

# Add everything from given fodler, optionally pass size
htd_catalog__add_from_folder()
{
  test -n "$2" || set -- "$1" -1
  use_find=1 htd_catalog__add_all_larger "$1" "$2"
}

# Add every untracked file, larger than
htd_catalog__add_all_larger() # DIR SIZE
{
  test -n "$1" || set -- . "$2"
  test -n "$2" || set -- "$1" 1048576
  note "Adding larger than '$2' from '$1'"
  htd_catalog__listtree "$1" | while read fn
  do
    test -e "$fn" -a \( -h "$fn" -o -f "$fn" \) || {
      warn "File expected '$fn'" ; continue ; }
    test $2 -lt $(filesize "$fn") || return
    htd_catalog__add_file "$fn" || { r=$?
      test $r -eq 2 && continue
      error "Adding '$fn' ($r)"
    }
  done
}

# See listtree, check all files for catalog entry or echo local path
htd_catalog__untracked()
{
  htd_catalog__listtree "$1" | while read fn
  do
    test -f "$fn" || continue
    htd_catalog__has_file "$fn" && continue
    echo "$fn"
  done
}

# Copy record between catalogs (eval record)
htd_catalog__copy_by_name() # CATALOG NAME [ DIR | CATALOG ]
{
  test -n "$1" || set -- $CATALOG "$2" "$3"
  record="$( htd_catalog__as_json "$1" | jq -c ' .[] | select(.name=="'"$2"'")' )"
  test -f "$3" || {
    test -d "$3" && {
      set -- "$1" "$2" "$(htd_catalog__name "$3" || echo $CATALOG_DEFAULT)"
    }
  }
  dest_dir="$(dirname "$3")/"

  test -s "$3" || echo "[]" > $3
  rotate_file "$3"
  htd_catalog__as_json "$3" | eval jq -c \'. += [ $record ]\' | jsotk json2yaml - > $3
}

# Get path for record, or find it by searching for basename
htd_catalog__record_get_path() # Record [Name]
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
htd_catalog__drop() # NAME
{
  htd_catalog__drop_by_name "" "$1"
}

# Remove record and src-file by name
htd_catalog__delete() # NAME
{
  htd_catalog__drop_by_name "" "$1"
  htd_catalog__record_get_path "$record" "$1" && {
    rm -v "$src_path" || return
  } || {
    warn "No file to delete, '$1' is already gone"
  }
}

htd_catalog__drop_by_name() # [CATALOG] NAME
{
  test -n "$1" || set -- $CATALOG "$2"
  test -s "$1" && backup_file "$1" || echo "[]" > $1
  htd_catalog__as_json "$1" |
      jq -c ' del( .[] | select(.name=="'"$2"'")) ' |
      jsotk json2yaml --pretty - "$1"
}

# Copy record and file
htd_catalog__copy() # CATALOG NAME [ DIR | CATALOG ]
{
  htd_catalog__copy_by_name "$1" "$2" "$3" || return
  htd_catalog__record_get_path "$record" "$2" || error "Lookup up file '$2'" 1
  test -e "$src_path" || error "Can't find file '$2'" 1
  mkdir -v "$(dirname "$dest_dir$src_path")" || return
  rsync -avzu "$src_path" "$dest_dir$src_path"
}

# Transfer record and move file
htd_catalog__move() # [CATALOG] NAME [ DIR | CATALOG ]
{
  htd_catalog__copy_by_name "$1" "$2" "$3" || return
  htd_catalog__record_get_path "$record" "$2" || error "Lookup up file '$2'" 1
  test -e "$src_path" || error "Can't find file '$2'" 1
  mkdir -vp "$(dirname "$dest_dir$src_path")" || return
  mv -v "$src_path" "$dest_dir$src_path" || return
  htd_catalog__drop_by_name "$1" "$2"
}


# Echo src/via URL YAML key-values to append to catalog in raw mode
htd_catalog__file_wherefrom() # ~ Src-File
{
  wherefrom_sh="$(wherefrom "$1" 2>/dev/null )" || {
    $LOG "error" "$scriptname $subcmd Error" "Retrieving wherefrom" "$1" 1
  }
  test -z "$wherefrom_sh" || {
    eval $wherefrom_sh
    echo "  source-url: '$url'"
    echo "  via: '$via'"
  }
}


# Echo first-seen YAML key-values to append to catalog in raw mode
htd_catalog__file_birth_date() # ~ Src-File
{
  dob_ts=$(filebtime "$1")
  test $dob_ts -ne 0 || dob_ts=$(filemtime "$1") || return

  dob=$($gdate --date="@$dob_ts" +"%Y-%m-%dT%H:%M:%S%z" | sed 's/^\(.*\)\(..\)$/\1:\2/')
  dob_utc=$(TZ=GMT $gdate --date="@$dob_ts" +"%Y-%m-%dT%H:%M:%SZ")
  echo "  first-seen-local: '$dob'"
  echo "  first-seen: '$dob_utc'"
}

# Set one key/string-value pair for one record in catalog
htd_catalog__set_key() # [Catalog] Entry-Id Key Value [Entry-Key]
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
    htd_catalog__as_json "$1" | {
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

# Like htd-catalog-set-key, except allow for JSON values to update a single
# entry key value, or a JQ script-file to do any JSON update
htd_catalog__update() # ~ [Catalog] ( Jq-Script | Entry-Id JSON-Value [Entry-Key] )
{
  local jq_scr=
  test -n "$1" || set -- "$CATALOG" "$2" "$3" "$4"
  test -f "$2" -a -z "$3" -a -z "$4" && {
      jq_scr="$2"
    } || {
      test -n "$2" || error "catalog-set: 2:Entry-ID required" 1
      test -n "$3" || error "catalog-set: 3:Value required" 1
      test -n "$4" || set -- "$1" "$2" "$3" "name"
    }

  trueish "$catalog_backup" && {
    backup_file "$1" || return
  }
  {
    htd_catalog__as_json "$1" | {
      test -z "$jq_scr" && {
        jq "map(select(.$4==\""$2"\") += $3 )" || return $?
      } || {
        jq -f "$jq_scr" - || return $?
      }
    } | sponge | jsotk json2yaml - $1

  } || { r=$?
    # undo copy
    not_trueish "$catalog_backup" || mv "$dest" "$1"
    return $?
  }
}

# Add/update entries from Annex. Even if a file does not exist, this can take
# keys, tags and other metadata from GIT annex. See annex-metadata. The
# standard SHA256E backend provides with bytesize and SHA256 cksum metadata.
htd_catalog__from_annex() # ~ [Annex-Dir] [Annexed-Paths]
{
  test -n "$1" || { shift ; set -- "." "$@" ; }
  local jq_scr="$PWD/.cllct/annex-update.jq" r='' cwd="$PWD"
  mkdir -p .cllct ; rm -f "$jq_scr"
  # Change to Annex Dir and get metadata
  cd "$1" || error "Annex dir expected '$1'" 1
  note "PWD: $PWD"
  shift
  note "Now building JQ update script <$jq_scr>..."
  annex_list $@ | metadata_keys=1 metadata_exists=1 annex_metadata |
      while read -d $'\f' block_
  do
    block="$(echo "$block_" | sed 's/=\(.*[^0-9].*\)\ *$/="\1"/g' )"
    eval $(echo "$block" | grep 'name=')
    note "Importing $name JSON.."
    json="$(echo "$block" | jsotk.py dump -I pkv)"
    std_info "JSON for $name: $json"
    test ! -s "$jq_scr" || printf " |\\n" >>"$jq_scr"
    grep -q "name:[\\ \"\']$name" $CATALOG && {
      printf -- "map(if .name==\"$name\" then . * $json else . end )" >>"$jq_scr"
    } || {
      printf -- ". += [ $json ]" >>"$jq_scr"
    }
    # XXX: catalog_backup=0 htd_catalog__update "" "$name" "$json"
  done
  # Update catalog now
  note "Done building script, executing catalog update..."
  cd "$cwd"
  update_json=1 htd_catalog__update "" "$jq_scr" || r=$?
  rm "$jq_scr"
  return $r
}

htd_catalog__from_annex_json()
{
  # XXX: JSON directly makes it hard to filter -lastchanged out..?
  # XXX: Annex 5.2 json output is botched,

  annex_metadata_json
#    |
#      while { read file && read fields ; }
#      do
#          #htd_catalog__set "" "$file" "$fields"
#          echo "file='$file' fields='$fields'"
#          #echo "{\"name\":\"$(basename "$file")\",$fields}"
#      done
}

# TODO: Import files from LFS test-server content dir (by SHA2)
htd_catalog__lfs_import()
{
  lfs_content_list "$1"
}

# TODO: import all checksum table files
htd_catalog__ck_import()
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
htd_catalog__consolidate()
{
  test -n "$1" || set -- "."
  htd_catalog__listtree | while read fpath
  do
    case "$fpath" in

      *.md5|*.md5sum ) ;;
      *.sha1|*.sha1sum ) ;;

      *.meta ) ;;
      catalog.y*ml|*/catalog.y*ml ) ;;

      * )
          note "Scanning for unknown file '$fpath'..."
  # Use quickest checksum and start for global lookup
          echo md5 $() |
          htd_catalog__scan_for "$fpath"
        ;;

    esac
  done
}
htd_catalog__cons() { htd_catalog__consolidate "$@"; }

# TODO: consolidate data from metafiles
htd_catalog__consolidate_metafiles()
{
  find ./ -iname '*.meta' | while read metafile
  do
    htd_catalog__add_file "$metafile"
  done
  #find ./ \( -iname '*.sha1*' -o -iname '*.md5*' \)
}

# TODO: merge all local catalogs (from subtrees to PWD)
htd_catalog__consolidate_catalogs()
{
  htd_catalog__req_local | while read catalog; do
    sameas "$CATALOG" "$catalog" && continue
    note "TODO: $catalog"
  done
}

# Call appropiate scan_for per checksum name, hash pair read on stdin
# Scan-for sequires local or global catalogs list
htd_catalog__scan_for()
{
  while read -r ck key
  do
    std_info "Scanning catalogs for $ck of $1..."
    htd_catalog__scan_for_${ck} "$key" && return
  done
}

htd_catalog__scan_for_md5()
{
  note "Looking for MD5: $1..."
  while read -r catalog
  do
    grep -q 'md5:\ '"$1" "$catalog" || continue
    echo "$catalog"
    return
  done < "$CATALOGS"
  return 1
}

# GIT uses SHA1, but has a peculiar content prefix
#htd_catalog__scan_for_sha1 "$1" && return

# Can also include some Annex backends and LFS
htd_catalog__scan_for_sha2()
{
  note "Looking for SHA2: $1..."
  while read catalog
  do
    grep -q 'sha2:\ '"$1" "$catalog"|| continue
    echo "$catalog"
    return
  done < "$CATALOGS"
  return 1
}

# Separate subtree entries. Go about by moving each file individually
htd_catalog__separate() # PATH
{
  test -d "$1" || error "dir expected" 1
  while test $# -gt 0
  do
    htd_catalog__listtree "$1" | while read filename
    do
       htd_catalog__move "" "$filename" "$1"
    done
    shift
  done
}

htd_catalog__update_keys() # Entry-Id [Keys...]
{
  test -n "$1" || error "expected properties to update" 1
  # Get entry name
  local fn="$1" ; shift
  local bn="$(basename "$fn" | sed 's/"/\\"/g')" pn="$(find . -iname "$fn" | head -n 1)"
  test -e "$pn" || error "No file '$pn'" 1
  # Add/update each property
  test -n "$*" || set -- mediatype format
  while test $# -gt 0
  do
    case "$1" in
      mediatype ) htd_catalog__set_key "" "$bn" "mediatype" "$(filemtype "$pn")" ;;
      format ) htd_catalog__set_key "" "$bn" "format" "$(fileformat "$pn")" ;;
      * ) error "unknown update '$1'" 1 ;;
    esac
    shift
  done
}

htd_catalog__update_all()
{
  test -n "$1" || error "expected properties to update" 1
  htd_catalog__listtree | while read fn
  do
    test -f "$fn" || continue
    htd_catalog__has_file "$1" || continue
    htd_catalog__update_keys "$fn" "$@" || {
      error "Updating '$fn"
      continue
    }
  done
}

htd_catalog__addempty()
{
  test -n "$1" || set -- "$CATALOG"

  test ! -s "$1" || {
    htd_catalog__get_by_key "$1" \
      $empty_sha2 && {
        warn "Existing record found" 1
      }
  }

  test -f "$1" || {
    test -d "$1" && {
      set -- "$(htd_catalog__name "$1" || echo $CATALOG_DEFAULT)"
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

#htd_catalog__dedupe() # DIR|GLOB|-
#{
#  htd_catalog__untracked | while read fn
#  do
#
#
#  local \
#      sha1sum=$(sha1sum "$1" | awk '{print $1}')
#  htd_catalog__check_keys "$sha1sum" && {
#    echo "add-file: $1" >>$Catalog_Duplicates
#    warn "Keys for '$1' present, matching record:"
#    # NOTE: don't update JSON while check-keys doesn't either
#    update_json=false \
#    htd_catalog__get_by_key "" "$sha1sum" | tee -a $Catalog_Duplicates
#    return 1
#  }
#  done
#}

# Assume annex is fully synced. Update catalog for missing files, and drop
# annexed paths .
htd_catalog__cleanup_annex_missing()
{
  #test -s .cllct/annex-missing.list || {
  #  git annex get . | grep '^get' | sed 's/get\ \(.*\)\ (not\ available)/\1/g' > .cllct/annex-missing.list
  #}

  # Prepare to remove files by saving key/metadata
  htd catalog from-annex . --not --in .

  # Drop paths
  git annex list --not --in . | while read path
  do
    test -h "$path" -a ! -e "$path" || {
      warn "Broken symlink path expected '$path'"
      continue
    }
    git rm "$path"
  done
}

# Create simple one-file-per-line manifests for files, bytesize, sha2 and name
catalog_sha2list()
{
  test -n "$1" || set -- .cllct/catalog.sha2list
  while read -r filename
  do
    test -e "$filename" || return
    filesize "$filename" | tr -d '\n\r'
    printf -- " "
    shasum -a 256 "$filename" | tr -d '\n\r'
    test -n "$reason" && printf "\t$reason\n" || printf "\n"
  done >> "$1"
}

# Get an checksum manifest by unpacking and checksumming, and insert size
catalog_archive_manifest() # Archive-File
{
  case "$1" in

    *.tar* ) catalog_tar_archive_manifest "$1" ;;
    *.zip ) catalog_zip_archive_manifest "$1" ;;

    *.rar ) echo "TODO rar" ;;
    *.7z ) echo "TODO 7z" ;;

    * ) stderr 0 "Unknown archive '$1'" ; return 1 ;;

  esac
}

# Unpack and use catalog_sha2list to build a content manifest
catalog_tar_archive_manifest()
{
  local archive="$(realpath "$1")" ext=$(filenamext "$1")
  test -s "$archive" || return 1
  test "$ext" = "tar" || ext=tar.$ext
  local catalog="$(pathname "$1" .$ext).sha2list"
  test -e "$catalog" && return
  printf -- "Creating SHA256 manifest for $(basename "$1")..."
  local name_key=$(echo "$1" | sha1sum - | tr -d '\n -')
  mkdir -p ".cllct/tmp/$name_key.$ext"
  local tmpdir="$(realpath .cllct/tmp/$name_key.$ext)"
  (
    cd "$tmpdir" || return
    printf -- " unpacking.."
    tar xf "$archive" || return
    printf -- " hashing all files.."
    find . -type f | catalog_sha2list ../catalog.sha2list
    printf -- " OK."
  )
  mv .cllct/tmp/catalog.sha2list "$catalog"
  rm -rf "$tmpdir"
  echo " New catalog $(basename "$catalog")"
}

# Unpack and use catalog_sha2list to build a content manifest
catalog_zip_archive_manifest()
{
  local archive="$(realpath "$1")" ext=$(filenamext "$1")
  test -s "$archive" || return 1
  local catalog="$(pathname "$1" .$ext).sha2list"
  test -e "$catalog" && return
  printf -- "Creating SHA256 manifest for $(basename "$1")..."
  local name_key=$(echo "$1" | sha1sum - | tr -d '\n -')
  mkdir -p ".cllct/tmp/$name_key.$ext"
  local tmpdir="$(realpath .cllct/tmp/$name_key.$ext)"
  printf -- " unpacking.."
  unzip -q "$archive" -d "$tmpdir" </dev/null || return
  (
    cd "$tmpdir"
    printf -- " hashing all files.."
    find . -type f | catalog_sha2list ../catalog.sha2list
    printf -- " OK."
  )
  mv .cllct/tmp/catalog.sha2list "$catalog"
  rm -rf "$tmpdir"
  echo " New catalog $(basename "$catalog")"
}

# Line-by-line rewrite for size-sha2-filename list to Annex SHA256E backend keys
lconv_sha2list_to_sha256e()
{
  awk '{
    ext=$0;
    gsub(/^.*\./,"",ext);
    gsub(/\t.*$/,"",ext);
    print "SHA256E-s"$1"--"$2"."ext}' "$@"
}

# Line-by-line rewrite for Annex SHA256E backend keys to size-sha2-filename list
lconv_sha256e_to_sha2list()
{
  sed 's/SHA256E-s\([0-9]*\)--\([0-9a-f]*\)\(\..*\)/\1 \2 \3/g' "$@"
}

# List all keys now dropped, content can be safely removed if left unused
htd_catalog__droppedkeys()
{
  test -n "$1" || set -- .catalog/dropped.sha2list
  lconv_sha2list_to_sha256e "$1"
}

htd_catalog__doctree()
{
  test -n "$1" || set -- dev cabinet note Home Shop Application data
  # FIXME personal sysadmin web
  test -s .cllct/catalog.yml || {
    CATALOG=.cllct/catalog.yml htd_catalog__addempty
  }
  txt.py doctree "" "$@"
  txt.py doctree --print-name "" "$@"
  # xsl_ver=1 htd tpaths "$1"
}

# Catalog files by sha2sum, using temp dir

cllct_find_by_sha256e_keyparts()
{
  content_key="SHA256E-s${1}--${2}${3}"
  for annex in $content_annices
  do
    annex_contentexists "$annex" "$content_key" && {
      stderr 0 "Content for $fn found at $annex"
      return
    } || true
    annex_keyexists "$annex" "$content_key" && {
      stderr 0 "Key for $fn found at $annex"
      return
    } || true
  done
  annices_scan_for_sha2 "$2" && return
  return 1
}

cllct_sha256e_tempkey()
{
  name_key=$(echo "$1" | sha1sum - | tr -d '\n -')
  test -e .cllct/tmp/$name_key.sh || {
    {
    echo "descr=\"$(fileformat "$1" | sed "s/[\"\$\`]/\\&/g" )\""
    echo ext=$(filenamext "$1")
    echo size=$(filesize "$1")
    echo sha2=$(shasum -a 256 "$1" | cut -d ' ' -f1 )
    } >.cllct/tmp/$name_key.sh
    stderr 0 "New $name_key.sh for '$1'"
  }
  . ./.cllct/tmp/$name_key.sh || return 1
  test -z "$ext" || ext=.$ext
}

cllct_cons_by_sha256e_tempkey()
{
  test -n "$noact" || noact=1
  trueish "$noact" && pref=echo || pref=""
  test -n "$backup" || backup=0
  #test -n "$target" || target=~/htdocs/cabinet
  test -n "$target" || target="/srv/$(readlink /srv/annex-local)/backup"

  i=0
  mkdir -p .cllct/tmp
  find $1 -type f | while read -r fn
  do
    descr= ext= size= sha2=
    cllct_sha256e_tempkey "$fn"
    test "$sha2" = "$empty_sha2" && continue
    cllct_find_by_sha256e_keyparts $size $sha2 $ext && {
      i=$(( $i + 1 ))
      ls -la "$fn"
      $pref rm "$fn"
      $pref rm .cllct/tmp/$name_key.sh
      continue
    } || {
      warn file_warn "Missing $content_key" "$fn"
      trueish "$backup" && {
        test -e "$target/$fn" || {
          $pref mkdir -vp "$(dirname "$target/$fn")"
          $pref rsync -a "$fn" "$target/$fn"
        }
        $pref rm "$fn"
        $pref rm .cllct/tmp/$name_key.sh
      } || true
    }
    #printf "$i. "
  done
}
