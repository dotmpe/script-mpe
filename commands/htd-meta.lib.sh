#!/bin/sh


# htd.sh actions for table.names and checksum list files


req_arg_pattern="Pattern format"
req_arg_path="Path"


htd__name_tags_test()
{
  lib_load match
  match_name_vars $@
}


htd__name_tags()
{
  local pattern
  lib_load match
  req_arg "$1" 'name-tags' 1 pattern && shift 1|| return 1
  req_arg "$1" 'name-tags' 2 path && path="$1" || return 1
  c=0
  test "${path: -1:1}" = "/" && path="${path:0: -1}"
  test -d "$path" && {
    eval find "$path $find_ignores -o \( -type f -o -type l \) -a -print" \
    | while read p
    do
      echo $p
      match_name_vars "$pattern" "$p" 2> /dev/null
      #c=$(( $c + 1 ))
      #echo $c
      #echo
    done
  } || {
    error "Req dir arg" 1
  }
}


htd__name_tags_all()
{
  lib_load match
  req_arg "$1" 'name-tags-all' 1 path && path="$1" || return 1
  test "${path: -1:1}" = "/" && path="${path:0: -1}"
  test -d "$path" && {
    eval find "$path $find_ignores -o \( -type f -o -type l \) -a -print" \
    | while read p
    do
      match_names "$p"
    done
  } || {
    error "Req dir arg" 1
  }
}


htd_spc__update_checksums="update-checksums [TABLE_EXT]..."
htd__update_checksums()
{
  test -n "$1" || set -- ck sha1 md5
  local failed=$(setup_tmpf .failed)
  test $(echo table.*) != "table.*" || error "No tables" 1
  for CK in $1
  do
    test -e table.$CK || continue
    note "Updating $CK table..."
    htd__ck_prune $CK || echo "htd:update:ck-prune:$CK" >>$failed
    htd__ck_clean $CK || echo "htd:update:ck-prune:$CK" >>$failed
    htd__ck_update $CK || echo "htd:update:ck-prune:$CK" >>$failed
    note "Update $CK table done"
  done
}


# Checksums frontend


htd_man_1__ck='Validate given table-ext, ck-files, or default table.$ck-exts set

Arguments are files with checksums to validate, or basenames and extensions to
check. With no file given, checks table.*
'
htd_spc__ck='ck [CK... | TAB...]'
htd__ck()
{
  local exts= ck_files=
  test -z "$*" && {
    exts="$ck_exts"
  }
  test -e "${1-}" && {
      ck_files="$*"
  } || {
    exts="$( for a in "$@" ; do \
      test -e "$a" && continue || echo "$a"; done | lines_to_words)"
    ck_files="$(ck_files "." $exts)"
  }

  for tab in $ck_files
  do
    # Skip unexpanded names and non-existing checksum tables
    test -e "$tab" || continue
    ck_run $tab || return $?
  done
}

htd_man_1__ck_add='Add new entries but dont hash'
htd_spc__ck_add="ck TAB [PATH|.]"
htd__ck_add()
{
  test -n "$1" || error "Need table to update" 1
  ck_run_update "$@" || error "ck-update '$1' failed" 1
}

htd__ck_init()
{
  test -n "$ck_tab" || ck_tab=table
  test -n "$1" || set -- ck "$@"
  test -n "$2" || set -- ck .
  touch $ck_tab.$1
  ck_arg "$1"
  shift 1
  htd__ck $ck_tab.$CK "$@"
}

htd__man_5_table_ck="Table of CK checksum, filesize and path"
htd__man_5_table_sha1="Table of SHA1 checksum and path"
htd__man_5_table_md5="Table of MD5 checksum and path"
# Either check table for path, or iterate all entries. Echoes checksum, two spaces and a path
htd__ck_table()
{
  lib_load match
  sh_isset ck_tab || local ck_tab=
  # table ext
  ck_arg "$1"
  test -n  "$1" && shift 1
  # second table ext
  test -n "$1" -a -e "$ck_tab.$CK.$1" && {
    S=$1; shift 1
  } || S=
  test -z "$1" && {
    {
      echo "#${T_CK}SUM  PATH"
      # run all entries
      cat $ck_tab.$CK$S | grep -Ev '^\s*(#.*|\s*)$' | \
      while read ckline_1 ckline_2 ckline_3
      do
        test "$CK" = "ck" && {
          cks=$ckline_1
          sz=$ckline_2
          p="$ckline_3"
        } || {
          cks=$ckline_1
          p="$ckline_2 $ckline_3"
        }
        echo "$cks  $p"
      done
    }
  } || {
    # look for single path
    htd_relative_path "$1"
    match_grep_pattern_test "$relpath" || return 1
    grep ".*\ \(\.\/\)\?$p_$" $ck_tab.$CK$S >> /dev/null && {
      grep ".*\ \(\.\/\)\?$p_$" $ck_tab.$CK$S
    } || {
      echo unknown
      return 1
    }
  }
}

htd_man_1__ck_table_subtree="Like ck-table, but this takes a partial path starting at the root level and returns the checksum records for files below that. "
htd_spc__ck_table_subtree="ck-tabke-subtree $ck_arg_spec <path>"
htd__ck_table_subtree()
{
  lib_load match
  ck_arg "$1"
  shift 1
  test -n "$1" || return 1
  match_grep_pattern_test "$1" || return 1
  grep ".*\ $p_.*$" table.$CK | grep -v '^\(\s*\|#.*\)$' | \
  while read -a ckline
    do
      test "$CK" = "ck" && {
        cks=${ckline[@]::1}
        sz=${ckline[@]::1}
        p="${ckline[@]:2}"
      } || {
        cks=${ckline[@]::1}
        p="${ckline[@]:1}"
      }
      echo "$cks  $p"
    done
}

# find all files, check their names, size and checksum
htd__ck_update()
{
  test -n "$choice_ignore_small" || choice_ignore_small=1
  # XXX: htd_find_ignores
  ck_write "$1"
  shift 1
  test -n "$1" || set -- .
  while test -e "$1"
  do
    update_p="$1"
    shift 1
    test -n "$update_p" || error "empty argument" 1
    test -d "$update_p"  && {
      note "Checking $T_CK for dir '$update_p'"
      ck_update_find "$update_p" || return $?
      continue
    }
    test -f "$update_p" && {
      note "Checking $T_CK for '$update_p'"
      ck_update_file "$update_p" || return $?
      continue
    }
    test -L "$update_p" && {
      note "Checking $T_CK for symlink '$update_p'"
      ck_update_file "$update_p" || return 4
      continue
    }
    warn "Failed updating '$PWD/$update_p'"
  done
  test -z "$1" || error "Aborted on missing path '$1'" 1
}

htd__ck_drop()
{
  lib_load match
  ck_write "$1"
  shift 1
  echo TODO ck_drop "$1"
  return
  req_arg "$1" 'ck-drop' 2 path || return 1
  match_grep_pattern_test "$1" || return 1
  cp table.$CK table.$CK.tmp
  cat table.$CK.tmp | grep "^.*$p_$" >> table.$CK.missing
  cat table.$CK.tmp | grep -v "^.*$p_$" > table.$CK
  rm table.$CK.tmp
}

htd_spc__ck_validate="ck-validate $ck_arg_spec [FILE..]"
htd__ck_validate()
{
  ck_arg "$1"
  shift 1
  test "$CK" = "ck" && {
    test -n "$1" && {
      for update_file in "$@"
      do
        htd__ck_table "$CK" "$update_file" | htd__cksum -
      done
    } || {
      htd__cksum table.$CK
    }
  } || {
    test -n "$1" && {
      for update_file in "$@"
      do
        htd__ck_table "$CK" "$update_file" | ${CK}sum -c -
      done
    } || {
      # Chec entire current $CK table
      ${CK}sum -c table.$CK
    }
  }
  stderr ok "Validated files from table.$CK"
}

# check file size and cksum
htd__cksum()
{
  test -n "$1"  && T=$1  || T=table.ck
  test -z "$2" || error "Surplus cksum arguments: '$2'" 1
  cat $T | while read cks sz p
  do
    SZ="$(filesize "$p")"
    test "$SZ" = "$sz" || { error "File-size mismatch on '$p'"; continue; }
    CKS="$(cksum "$p" | awk '{print $1}')"
    test "$CKS" = "$cks" || { error "Checksum mismatch on '$p'"; continue; }
    note "$p cks ok"
  done
}
htd_spc__cksum="cksum [<table-file>]"

# Drop non-existant paths from table, copy to .missing
htd__ck_prune()
{
  ck_write "$1"
  shift 1
  stderr info "Looking for missing files in $CK table.."
  htd__ck_table $CK \
    | grep -Ev '^(#.*|\s*)$' \
    | while read cks p
  do
    test -e "$p" || {
      htd__ck_drop $CK "$p" \
        && note "TODO Dropped $CK key $cks for '$p'"
    }
  done
}

# Read checksums from *.{sha1,md5,ck}{,sum}
htd__ck_consolidate()
{
  htd_find_ignores
  test -n "$find_ignores" || error htd-$subcmd-find_ignores 1
  eval "find . $find_ignores -o -name '*.{sha1,md5,ck}{,sum}' -a \( -type f -o -type l \) " -print | while read p
  do
    echo "$p"
  done
}

# try to find files from .missing, or put them in .gone
# XXX: htd_man_1__ck_clean="Iterate checksum table, check for duplicates, normalize paths"
htd__ck_clean()
{
  ck_write "$1"
  shift 1
  test -s "table.$CK.missing" || {
    note "$T_CK.missing table does not exists, nothing to check"
    return
  }
  log "Looking for missing files from $CK table"/
  htd__ck_table $CK .missing | while read cks p
  do
    BN="$(basename "$p")"
    test -n "$BN" || continue
    NW=$(eval find ./ $find_ignores -o -iname '$BN' -a type f -a -print)
    test -n "$NW" && echo "$BN -> $NW"
  done
  echo 'TODO rewrite ck table path'
}

# TODO consolidate meta
htd__ck_metafile()
{
  [ -n "$1" ] && d=$1 || d=.
  CK=sha1
  eval find $d $find_ignores -o -iname \'*.meta\' -print \
  | while read metafile
  do
    ck_mf_p="$(dirname "$metafile")/$(basename "$metafile" .meta)"
    [ -e "$ck_mf_p" ] || {
      echo "missing source file $metafile: $ck_mf_p"
      continue
    }
    cks=$(rsr.py --show-sha1sum-hexdigest "$ck_mf_p" 2> /dev/null)
    htd__ck_table "$CK" "$ck_mf_p" > /dev/null && {
      log "$cks found"
    } || {
      CKS=$(${CK}sum "$ck_mf_p" | cut -d' ' -f1)
      #echo CKS=$CKS cks=$cks
      test "$cks" = "$CKS" && {
        log "$CKS ok $ck_mf_p"
      } || {
        error "Corrupt file: $ck_mf_p"
        continue
      }
      echo "$CKS  $ck_mf_p" >> table.$CK
    }

  done
}

#
