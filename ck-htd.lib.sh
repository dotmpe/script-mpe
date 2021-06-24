#!/bin/sh


# Deal with checksumming, and file manifests with checksums


ck_htd_lib_load()
{
  test -n "${ck_tab-}" || ck_tab=table
  test -n "${ck_exts-}" || ck_exts="ck crc32 md5 sha1 sha2 sha256"
  empty_md5=d41d8cd98f00b204e9800998ecf8427e
  empty_sha1=da39a3ee5e6b4b0d3255bfef95601890afd80709
  empty_sha2=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  empty_git=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
}

ck_exists()
{
  test -n "${1-}" || set -- .
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

# Read ck key and file path on stdin, and verify cksums. ck-key is '<CK>:' prefix to checksum
# TODO any=1 to stop at first supported key that validates
# TODO: all=1 (default) require each and at least one key to be valid, but ignore unsuppored
ck_validate()
{
  while IFS=$IFS: read -r ck cksum fn
  do
    ck_$ck "$fn" "$cksum" || {
      error "Invalid $ck:$cksum <$fn>"
      return 1
    }
    note "Validated $ck:$cksum <$fn>"
  done
}


# Run checksums from file [one checksum type per file, see ck_validate to
# run individual ``*sum -c`` invocations per line on stdin]
ck_run() # CkTable
{
  test -n "$1" || error "ck-run argument expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1
  ext="$(filenamext "$1")"
  note "Using $ext external to check '$1'"
  { case "$ext" in
        sha2 | sha256 )
              shasum -a 256 -c $1 || return $?
            ;;
        git | rhash-* )
              cksum.py -a $ext -c $1 || return $?
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

# Read checksums from catalog.yml.
ck_read_catalog () # ~ CATALOG [CK-KEYS..]
{
  test -e "$1" || error "ck_read_catalog: No such catalog '$1'" 1
  local l=-1 cat="$1" basedir="$(dirname "$1")" fname= name= host= fkv= keys= \
      catalog_sh="$(dotname "$(pathname "$1" .yaml .yml)")"

  fkv="$( jsotk.py --output-prefix=catalog to-flat-kv "$1")" || return $?
  shift 1
  test $# -eq 0 && {
    test ${all_keys:-0} -eq 1 && {
      keys="$( echo "$fkv" | grep '[0-9]*_keys_' | sed 's/^catalog__[0-9]*_keys_\([^=]*\)=.*/\1/' | sort -u)"
    } || {
      keys="$( echo $ck_exts | tr '-' '_' )"
    }
  } || keys="$*"

  note "Scanning '$(lines_to_words "$keys")' in $cat.."
  eval "$fkv" || return $?
  local var
  while true
  do
    l=$(( $l + 1))
    var=catalog__${l}_name
    name="${!var:-}"
    var=catalog__${l}_path
    fname="${!var:-}"
    test -n "$name" -o -n "$fname" || {
       # No more entries, either path or name is required
       break
    }
    test -n "$fname" && name="$(basename "$fname")" || {
      test -n "$name" && fname="$(find_one . "$name")"
    }

    var=catalog__${l}_exists
    falseish "${!var:-true}" && {
      debug "Skipped missing '$name'"
      continue
    }
    var=catalog__${l}_contexts__0
    test -z "${!var:-}" || {
      debug "Skipped contained '$name'"
      continue
    }

    var=catalog__${l}_host
    host="${!var:-}"
    # TODO canon="$(canon_host '' "$host" || echo "$host")"
    test -z "$host" -o "$hostname" = "$host" || {
      warn "Not on host? $host entry #$l '$name'" ; l=$(( $l + 1)) ; continue
    }

    true "${fname:="$name"}"
    fnmatch "* *" "$fname" && fname="$(echo "$fname" | sed 's/\ /\\ /g')"
    for ck in $keys
    do
      var=catalog__${l}_keys_${ck}
      key="${!var:-}"
      test -n "$key" || continue
      fnmatch "* *" "$key" && key="$(echo "$key" | sed 's/\ /\\ /g')"
      echo "$key $ck $fname"
    done

  done
  std_info "Done reading checksums from catalog '$cat'"
}

ck_run_catalog () # ~ CATALOG [CK-KEYS]
{
  local cat="$1" dir="$(dirname "$1")"
  test -d "$dir" || { warn "Missing dir '$cat'" 1; }
  test -f "$cat" || { warn "Missing file '$cat'" 1; }

  {
    ck_read_catalog "$@"
  } | {
    cd "$dir"
    local key ck name namecnt=0 failcnt=0 keycnt=0 ret=0 r names=
    while read key ck name ; do
      fnmatch "*:$name:*" ":$names:" && {
        test ${choice_all:-0} -eq 1 && {
          true
        } || {
          continue
        }
      } || namecnt=$(( $namecnt + 1 ))
      keycnt=$(( $keycnt + 1 ))

      r=0
      debug "Key $keycnt:'$key' CK:$ck Name:'$name'"
      test -e "$name" || { r=$?
        failcnt=$(( $failcnt + 1 ))
        echo "NOT OK file $name"
        error "No file '$name' for $ck:$key"
      }
      test -e "$name" && case "$ck" in

          # Special case SHA-2
          sha2* | sha3* | sha5* )
                l=$(echo $ck | cut -c4-)
                echo "$key  $name" | {
                    test "$l" != "2" || l=256
                    shasum -s -a $l -c - ; r=$?
                    test 0 -eq $r && echo "OK $ck $name" || {
                        failcnt=$(( $failcnt + 1 ))
                        echo "NOT OK $ck $name"
                        warn "Failed $ck '$key' for '$name'"
                    }
                }
              ;;

          # Special case for CK (a CRC+Size)
          ck | *crc32 )
                cks=$(echo "$key" | cut -f 1 -d ' ')
                sz=$(echo "$key" | cut -f 2 -d ' ')
                SZ="$(filesize "$name")"
                test "$SZ" = "$sz" && {
                  test $ck = ck && {
                    CKS="$(cksum "$name" | awk '{print $1}')"
                  } || {
                    test $ck != crc32 || ck=rhash-crc32
                    CKS="$(cksum.py -a $ck "$name" | awk '{print $1}')"
                  }
                  test "$CKS" = "$cks" && echo "OK $ck $name" || { r=$?
                    failcnt=$(( $failcnt + 1 ))
                    echo "NOT OK $ck $name"
                    warn "Checksum mismatch on $PWD '$ck:$name'"
                  }
                } || { r=$?
                  failcnt=$(( $failcnt + 1 ))
                  echo "NOT OK $ck $name"
                  warn "File-size mismatch on '$ck:$name'";
                }
              ;;

          git | rhash-* )
                echo "$key  $name" | {
                    cksum.py -a $ck -c -; r=$?
                    test 0 -eq $r && echo "OK $ck $name" || {
                        failcnt=$(( $failcnt + 1 ))
                        echo "NOT OK $ck $name"
                        warn "Failed $ck '$key' for '$name'"
                    }
                }
              ;;

          # Default to generic <ck>sum CLI tools
          * )
                echo "$key  $name" | {
                    ${ck}sum --status -c -; r=$?
                    test 0 -eq $r && echo "OK $ck $name" || {
                        failcnt=$(( $failcnt + 1 ))
                        echo "NOT OK $ck $name"
                        warn "Failed $ck '$key' for '$name'"
                    }
                }
              ;;
      esac
      names=$names:$name
      test $r -eq 0 || ret=$r
    done

    test $keycnt -gt 0 || {
      error "No keys found"
      ret=4
    }
    test $ret -eq 0 && {
      note "Checked $namecnt names, $keycnt keys ($cat) OK"
    } || {
      warn "Checked $namecnt names, $keycnt keys: $failcnt failures ($cat)"
      return $ret
    }
  }
}

# Check keys from catalog corresponding to known checksum algorithms
ck_run_catalogs()
{
  local cwd=$PWD dir= catalog= ret=0

  note "Running over catalogs found in '$cwd'..."
  { htd_catalog__list_files || exit $?
  } | {
    while read catalog
    do
      note "Found catalog at '$catalog'"
      ck_run_catalog "$catalog" || ret=$?
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

  while test $# -gt 0
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
      std_info "Adding one file '$1'"
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
  std_info "Reading $T_CK, looking for files '$1'"
  find_p="$(strip_trail=1 normalize_relative "$1")"

  sh_isset failed || {
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

file_sha1()
{
  while read -r file
  do
    sha1sum "$file"
  done
}

file_sha2()
{
  while read -r file
  do
    shasum -a 256 "$file"
  done
}
