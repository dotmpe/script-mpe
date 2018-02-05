#!/bin/sh


# Deal with checksumming, and file manifests with checksums


ck_lib_load()
{
  test -n "$ck_tab" || ck_tab=table
  test -n "$ck_exts" || ck_exts="ck md5 sha1 sha256"
}

ck_exists()
{
  test -n "$1" || set -- .
  test_glob "$1/$ck_tab.{$(echo "$ck_exts" | tr ' ' ',')}"
}

ck_files()
{
  local d=$1 ; shift
  test -n "$*" || set -- $ck_exts
  bash -c "echo $d/$ck_tab.{$(echo "$@" | tr ' ' ',')}"
}

ck_arg_spec="[ck|sha1|md5]"
ck_arg()
{
  test -n "$1"  && CK=$1  || CK=ck
  test -e $ck_tab.$CK || {
    error "First argument must be CK table extension, no such table: $ck_tab.$CK" 1
  }
  test -r $ck_tab.$CK || {
    error "Not readable: $ck_tab.$CK" 1
  }
  T_CK="$(echo $CK | tr 'a-z' 'A-Z')"
}

ck_run()
{
  test -n "$1" || error "ck-run argument expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1
  ext="$(filenamext "$1")"
  { case "$ext" in
        sha256 )
              shasum -a 256 -c $1 || return $?
            ;;
        ck )
              htd__cksum $1 || return $?
            ;;
        * )
              ${ext}sum -c $1 || return $?
            ;;
    esac
  } | sed 's/:\ /: '$ext' /g'
}

# Read checksums from catalog.yml
ck_read_catalog()
{
  local l=0 basedir="$(dirname "$1")" fname= name= host= \
      catalog_sh="$(dotname "$(pathname "$1" .yaml .yml)")"

  # TODO: look for document type, version
  eval $( jsotk.py --output-prefix=catalog to-flat-kv "$1" || exit $? ) ||
    return $?

  while true
  do
    host="$(eval echo \"\$catalog__${l}_host\")"
    test -z "$host" -o "$hostname" = "$(canon_host '' $host)" || {
        l=$(( $l + 1)) ; continue
    }

    name="$(eval echo \"\$catalog__${l}_name\")"
    fname="$(eval echo \"\$catalog__${l}_path\")"
    test -n "$name" -o -n "$fname" || {
       # No more entries, either path or name is required
       break
    }

    test -n "$fname" && name="$(basename "$fname")" || {
        test -n "$name" && fname="$(find_one . "$name")"
    }
    test -n "$fname" -a -e "$fname" || {
        warn "Missing name/path for entry $l. $name" ; return 1; }

    test -f "$fname" && {
      for ck in $( echo $ck_exts | tr '-' '_' )
      do
        key="$(eval echo \"\$catalog__${l}_keys_${ck}\")"
        test -n "$key" || continue

        fnmatch "* *" "$key" && key="$(echo "$key" | sed 's/\ /\\ /g')"
        fnmatch "* *" "$fname" && fname="$(echo "$fname" | sed 's/\ /\\ /g')"
        echo "$key $ck $fname"
      done
    }

    l=$(( $l + 1))
  done
  info "Done reading checksums from catalog '$1'"
}

# Check keys from catalog corresponding to known checksum algorithms
ck_run_catalogs()
{
  local cwd=$(pwd) dir= catalog= ret=0

  note "Running over catalogs found in '$cwd'..."
  { htd_catalog_list || exit $?
  } | {
    while read catalog
    do
      note "Found catalog at '$catalog'"
      dir="$(dirname "$catalog")"
      cd "$cwd"
      test -d "$dir" || { warn "Missing dir '$catalog'" ; continue ; }
      test -f "$catalog.yml" || { warn "Missing file '$catalog'" ; continue ; }

      cd "$dir"
      {
        ck_read_catalog "$(basename "$catalog.yml")"
        test 0 -eq $? || { ret=1; break; }
      } | {
        while read key ck name ; do

          debug "Key: '$key' CK: $ck Name: '$name'"
          fnmatch "* $ck *" " $ck_exts " || continue
          test -e "$name" || { error "No file '$name'" ; return 1 ; }
          case "$ck" in

              # Special case for some larger SHA-1
              sha2* | sha3* | sha5* )
                    l=$(echo $ck | cut -c4-)
                    echo "$key  $name" | { r=0
                        shasum -s -a $l -c - || r=$?
                        test 0 -eq $r && echo "$name: ${ck} OK" || {
                            warn "Failed $ck '$key' for '$name'"
                            return $r
                        }
                    }
                  ;;

              # Special case for CK (CRC/Size)
              ck )
                    cks=$(echo "$key" | cut -f 1 -d ' ')
                    sz=$(echo "$key" | cut -f 2 -d ' ')
                    SZ="$(filesize "$name")"
                    test "$SZ" = "$sz" || { error "File-size mismatch on '$p'"; return 1; }
                    CKS="$(cksum "$name" | awk '{print $1}')"
                    test "$CKS" = "$cks" || { error "Checksum mismatch on '$p'"; return 1; }
                    echo "$name: ${ck} OK"
                  ;;

              # Default to generic <ck>sum CLI tools
              * )
                    echo "$key  $name" | { r=0
                        ${ck}sum -s -c - || r=$?
                        test 0 -eq $r && echo "$name: ${ck} OK" || {
                            warn "Failed $ck '$key' for '$name'"
                            return $r
                        }
                    }
                  ;;
          esac

          test 0 -eq $? || {
            return 1
          }
        done
      }
      r=$?

      test 0 -eq $r -a $ret -eq 0 || {
        error "failure in '$catalog' ($r, $ret)"
        return 1
      }
    done
  }
  test 0 -eq $? || ret=1
  cd "$cwd"
  test 0 -eq $ret || return 1
}

ck_run_update()
{
  local table=$1 \
    ck_find_ignores="-name 'manifest.*' -prune \
      -o -name 'table.ck' -prune \
      -o -name 'table.sha1' -prune \
      -o -name 'table.md5' -prune"
  shift
  test -n "$1" || error "Need path to update table for " 1
  test -z "$find_ignores" \
    && find_ignores="$ck_find_ignores" \
    || find_ignores="$find_ignores -o $ck_find_ignores"

  while test -n "$1"
  do
    test -e "$1" || error "No such path to check: '$1'" 1
    test -d "$1" && {
      note "Adding dir '$1'"
      {
        eval find "$1" $find_ignores -o -type f -exec ${CK}sum "{}" + || return $?
      } > $table
      shift
      continue
    }
    test -f "$1" && {
      info "Adding one file '$1'"
      ${CK}sum "$1" > $table
      shift
      continue
    }
    note "Skipped '$1'"
    shift
  done
  note "Updated CK table '$table'"
}

ck_write()
{
  ck_arg "$1"
  test -w $ck_tab.$CK || {
    error "Not writable: $ck_tab.$CK" 1
  }
}

ck_update_file()
{
  ck_write "$CK"
  test -f "$1" || error "ck-update-file: Not a file '$1'" 1
  update_file="$1"
  # FIXME use test name again but must have some testcases
  # to verify because currently htd_name_precaution is a bit too strict
  # htd__test_name
  match_grep_pattern_test "$update_file" > /dev/null || {
    error "Skipped path with unhandled characters"
    return
  }
  test -r "$update_file" || {
    error "Skipped unreadable path '$update_file'"
    return
  }
  test -d "$update_file" && {
    error "Skipped directory path '$update_file'"
    return
  }
  test -L "$update_file" && {
    BE="$(dirname "$update_file")/$(readlink "$update_file")"
    test -e "$BE" || {
      error "Skip dead symlink"
      return
    }
    SZ="$(filesize "$BE")"
  } || {
    SZ="$(filesize "$update_file")"
  }
  test "$SZ" -ge "$MIN_SIZE" || {
    # XXX: trueish "$choice_ignore_small" \
    warn "File too small: $SZ"
    return
  }
  # test localname for SHA1 tag
  BN="$(basename "$update_file")"
  # XXX hardcoded to 40-char hexsums ie. sha1
  HAS_CKS="$(echo "$BN" | grep '\b[0-9a-f]\{40\}\b')"
  cks="$(echo "$BN" | grep '\b[0-9a-f]\{40\}\b' |
    sed 's/^.*\([0-9a-f]\{40\}\).*$/\1/g')"
  # FIXME: normalize relpath
  test "${update_file:0:2}" = "./" && update_file="${update_file:2}"
  #EXT="$(echo $BE)"

  test -n "$HAS_CKS" && {
    htd__ck_table "$CK" "$update_file" > /dev/null && {
      echo "path found"
    } || {
      grep "$cks" table.$CK > /dev/null && {
        echo "$CK duplicate found or cannot grep path"
        return
      }
      CKS=$(${CK}sum "$update_file" | cut -d' ' -f1)
      test "$cks" = "$CKS" || {
        error "${CK}sum $CKS does not match name $cks from $update_file"
        return
      }
      echo "$cks  $update_file" >> table.$CK
      echo "$cks added"
      return
    }
    return
  } || {
    # TODO prepare to rename, keep SHA1 hashtable
    htd__ck_table "$CK" "$update_file" > /dev/null && {
      note "Checksum present $update_file"
    } || {
      ${CK}sum "$update_file" >> table.$CK
      note "New checksum $update_file"
    }
  }
}

ck_update_find()
{
  info "Reading $T_CK, looking for files '$1'"
  find_p="$(strip_trail=1 normalize_relative "$1")"

  var_isset failed || {
    local failed_local=1 failed=$(setup_tmpf .failed)
    test ! -e $failed || rm $failed
  }

  local paths=$(setup_tmpf .$subcmd)
  test ! -e $paths || rm $paths

  ck_update_find_inner()
  {
    test -n "$find_ignores" && {
      eval find "$find_p" $find_ignores -o -type f -print || return $?
    } || {
      find "$find_p" -type f -print || return $?
    }
  }

  ck_update_find_inner > $paths || {
    echo "htd:$subcmd:find-inner" >>$failed
    test ! -e $paths || rm $paths
  }

  while read p
  do
    ck_update_file "$p" || echo "htd:$subcmd:$p" >>$failed
  done < $paths

  test -s "$failed" \
    && warn "Failures: $T_CK '$1', $(count_lines $failed) targets" \
    || stderr ok "$T_CK '$1', $(count_lines $paths) files"
  rm -rf $paths
  test -z "$failed" -o ! -e "$failed" || rm $failed
}