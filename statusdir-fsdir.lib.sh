#!/usr/bin/env bash

sd_fsdir()
{
  local types="${fsd_types-"log index tree cache"}"
  local rtype="${fsd_rtype-"tree"}"
  local l g c r p= k="${2-}" ttl="${3-}" v="${4-}" time=$(date +'%s')
  sd_fsdir_settings &&
  local pref name suff ext new init &&
  sd_fsdir_inner "$@"
}

sd_fsdir_help='
  check
      Test that each recordtype is initialized.
  init [NAME [TTL [META]]
      Without arguments, initialize each recordtype.
      With argument, create a new file
  status NAME
    See that files are fresh or emit an error. TODO: track checksums
  validate
    TODO: Run status check for timestamp and checksum values
  get NAME
    Echo raw data
  set NAME [TTL] VALUE [TYPE [META]]
  incr
  del
  list
  list-all
  assert
  input NAME
    Read stdin to file.
  exec NAMES... [ CAPTURE ] -- CMDLINE...
    TODO: Execute and capture output, store stdout and optionally stderr or other
    streams or logs at names.
  commit
    TODO: store updated metadata
  ping
    A quick alternative to "check", no output and 0-return status if in order.
'

sd_fsdir_inner()
{
  r=0
  while test $# -gt 0
  do
    local act=$1 ; shift
    $LOG debug "" "FSDir running '$act', rest ($#):" "$*"
    case "$act" in

      check ) local act=init ; has_next_arg "$@" && { act=$1; shift; }
          has_no_arg "$@" || break
          sd_fsdir_check_$act
        ;;

      status ) has_no_arg "$@" || break
          sd_fsdir_check sd_fsdir_status -le 1 && {
            test $sd_fsdir_status -eq 0 &&
              $LOG ok "" "Status OK, age: $(file_modification_age "$g")" ||
              $LOG done "" "Status $sd_fsdir_status, age: $(file_modification_age "$g")"
          } || {
            $LOG note "" "Refreshing status $sd_fsdir_status, age: $(file_modification_age "$g")"
            # Be sure to commit directly after run, before other commands
            test $# -eq 0 && set -- commit || {
              fnmatch "* commit *" " $* " || set -- commit -- "$@"
            }
            # Now add arguments to this command: all names, and run
            set -- $( sd_fsdir_inner list-all ) -- "$@"
            while has_next_arg "$@"
            do sd_fsdir_entry_load "$1" && sd_fsdir_entry_validate || r=$?; shift
            done ; sd_fsdir_status=$r ; unset r
            local max_age="$( shell_cached \
                fmtdate_relative "" "${!varttl:-$STATUSDIR_CHECK_TTL}" "")"
            test $sd_fsdir_status -eq 0 &&
              $LOG ok "" "Status OK, just refreshed (max-age $max_age)" ||
              $LOG done "" "Status $sd_fsdir_status, just refreshed (max-age $max_age)"
          }
          r=$sd_fsdir_status
        ;;

      status-files )
          has_next_arg "$@" && break
          set -- status $( sd_fsdir_inner list-all-files )
          continue
        ;;

      validate )
          while has_next_arg "$@"
          do sd_fsdir_entry_load "$1" && sd_fsdir_entry_validate || r=$?; shift
          done
        ;;

      init ) test $# -eq 0 && {

            # Only to be run on the initial run and whenever fsd_types changes
            test -d "$STATUSDIR_ROOT" || {
              $LOG "error" "" "Statusdir should have been initialized" "" 1
            }
            local rtype; for rtype in $types
            do
              test -e "${STATUSDIR_ROOT}$rtype" || {
                mkdir -p "${STATUSDIR_ROOT}$rtype"
              }
              test -e "${STATUSDIR_ROOT}$rtype/.meta.sh" || {
                touch "${STATUSDIR_ROOT}$rtype/.meta.sh"
              }
            done
          } || {

            # Check for or initialize file if possible
            sd_fsdir_existing "$1" && {
              $LOG "error" "" "Entry exists" "$p/$k"
              return 1
            }
            init=1 sd_fsdir_entry_load "$@"
            shift $c
            unset c
          }
        ;;

      load ) # NAME [TTL [META]]
          sd_fsdir_entry_load "$@"
          shift $c
          unset c
        ;;

      unload ) # Record-Type Local-Name
          true
        ;;

      deinit )
          # TODO: cleanup given rtypes or existing rtypes not in list
          #test $# -eq 0 -o "${1}" = "--" && set -- $types
          #sd_fsdir_deinit "$@"
          while test $# -gt 0
          do
            find $STATUSDIR_ROOT$1/ -type d -empty -exec echo rm {} \;
            shift
            test "${1-}" != "--" || break
          done
        ;;
      get ) # NAME
          test -n "$p" || { has_next_arg "$@" || return
            set -- load "$1" -- $act "$@"; continue; }
          shift 1
          test -e "$p/$k" && echo "$(cat "$p/$k")" || return
        ;;
      set ) # NAME [TTL] VALUE [TYPE [META]]
          test -n "$p" && {
            test ${new:-0} -eq 1 -o -z "$ttl" || {
              sd_fsdir_set $name ttl $ttl || return
            }
          } || {
            local type=${4:-data} meta=
            test $# -gt 3 && shift 4 || shift 3
            while has_next_arg "$@"
            do meta="$meta${meta+ }$1"; shift
            done
            init=1
            set -- load "$k" $ttl $meta -- $act "$@"; continue;
          }
          echo "$v" > "$p/$k"
        ;;
      append )
          local v=
          while has_next_arg "$@"
          do v="$v${v+ }$1"; shift
          done
          echo "$v" >> "$p/$k"
        ;;
      incr )
          v=$(fsdir get "$k" || return)
          v=$(( $v + 1 ))
          fsdir set "$k" "" "$v" || return
          echo "$v"
        ;;
      decr )
          v=$(fsdir get "$k" || return)
          v=$(( $v - 1 ))
          fsdir set "$k" "" "$v" || return
          echo "$v"
        ;;
      del )
          test -n "$p" || { set -- -- load "$1" -- $act "$@"; break; }
          rm $p/$k
          shift
        ;;
      list )
          echo $p/$k* | xargs -n1 basename
        ;;
      list-all )
          grep -hoP '^[a-z][a-z0-9]*(?=_ext=)' ${STATUSDIR_ROOT}*/.meta.sh
        ;;
      list-all-files ) (
            shopt -s nullglob
            for rtype in $types
            do exts=.list\ .tab basenames ${STATUSDIR_ROOT}$rtype/* ; done
          )
        ;;
      input )
          cat - > $p/$k
          shift
        ;;
      name )
          # test -n "$p" || { set -- -- load "$1" -- $act "$@"; break; }
          echo "$p/$k"
        ;;
      assert )
          test -d $p || mkdir -vp $p
          echo $p/$k
          shift
        ;;
      exec )
          echo "args '$*' v='$v' p='$p' pref='${pref-}' k='$k' ext='${ext-}' suff='${suff-}'" >&2
        ;;

      index ) # [prefvar=$1_name_prefix] [extvar=$1_extension] ~ Local-Name [Exists]
          { not_falseish "${2-}" || test -e "${STATUSDIR_ROOT}$rtype/$k"
          } || {
            $LOG error "" "No such $rtype '$1'" "${STATUSDIR_ROOT}$rtype/$k"
            return 2
          }

          test ${local:-0} -eq 1 && {
            lookup_first=${lookup_first:-1} lookup_path LUP $rtype/$k
            return $?
          }

          echo "${STATUSDIR_ROOT}$rtype/$k"
          shift
        ;;

      log )
          type=log statusdir_run index "$@"
          shift
        ;;

      commit ) has_no_arg "$@" || break
          grep -q "^sd_fsdir_status=$sd_fsdir_status\$" "$g" && touch "$g" || {
            sd_fsdir_set sd_fsdir_status "$sd_fsdir_status"
            $LOG "info" "" "Updated sd-fsdir-status" "$sd_fsdir_status"
          }
        ;;

      ping )
          test -e $STATUSDIR_ROOT
          return $?
        ;;

      * )
          $LOG error "" "FSDir:Error: $act? ($*)"
          exit 101
        ;;

    esac
    test $# -eq 0 || {
      test "${1-}" = "--" && shift || {
        $LOG "error" "" "Left-over arguments" "$*" 1
        return 1
      }
    }
  done

  return $r
}

sd_fsdir_settings ()
{
  g=${STATUSDIR_ROOT}meta.sh
  local rtype
  for rtype in $types
  do . ${STATUSDIR_ROOT}$rtype/.meta.sh || return
  done
}

sd_fsdir_entry_load ()
{
  local n=$#
  name=$1
  shift; has_next_arg "$@" && { ttl=$1; shift; }
  while has_next_arg "$@"
  do meta="${meta-}${meta+ }$1"; shift
  done
  c=$(( $n - $# ))
  sd_fsdir_load "$name" "${ttl-}" "${meta-}" || return
  p=$STATUSDIR_ROOT$rtype
  l=$p/.meta.sh
  k=$pref$name$suff.$ext
}

sd_fsdir_load () # TNAME [TTL [META]]
{
  ttl= ; new= ; p= ; k= ; rtype= ; pref= ; suff=
  sd_fsdir_existing "$1" || {
    $LOG error "" "New" "$1"
    sd_fsdir_new "$1" || {
      $LOG error "" "cannot create" "$1"
      return 1
    }; }
  test ${new:-0} -eq 0 -o ${init:-0} -eq 0 || {
    true "${rtype:="shell"}"
    l=$STATUSDIR_ROOT$rtype/.meta.sh
    $LOG note "" "New" "$rtype/$pref$name$suff.$ext"
    touch $STATUSDIR_ROOT$rtype/$pref$name$suff.$ext
    sd_fsdir_set ext $name $ext
    #test -z "$pref" || sd_fsdir_set $name pref ${pref:1}
    #test -z "$suff" || sd_fsdir_set $name suff ${suff:1}
    test -z "$2" || sd_fsdir_set ttl $name "$2"
    test -z "$3" || sd_fsdir_set meta $name "$3"
    init=
    return
  }

  test $# -lt 3 && return
  shift 2
  local meta_var=${name}_meta meta
  meta=${!meta_var-}
  test $# -eq 0 -o -z "$1" || {
    $LOG error "" "Meta given but none for record '$name':" "$rtype:$ext <> $meta"
    return 1
  }
  for tag in $@
  do
    fnmatch "@*" "$tag" || continue
    echo "$meta" | grep -q "$tag" || {
      $LOG error "" "No match on meta for '$rtype/$name.$ext':" "$tag <> $meta"
      return 1
    }
  done
}

sd_fsdir_existing () # Name TTL Meta
{
  name=$(filestripext "$1" | tr -cd 'a-z0-9')
  local prefvar=${name}_prefix suffvar=${name}_suffix extvar=${name}_ext

  pref="${!prefvar-}"
  test -z "$pref" || pref=${pref}-
  suff="${!suffvar-}"
  test -z "$suff" || suff=-${suff}
  ext="${!extvar-}"

  sd_fsdir_rtype $name && {
    local ttl_var=${name}_ttl
    test -n "${ttl-}" || ttl=${!ttl_var-}
    new=0
    return
  } || {
    rtype=
    new=1
    return 1
  }
}

sd_fsdir_check_init () {
  local rtype; for rtype in $types
  do
    test -e "${STATUSDIR_ROOT}$rtype" -a \
      -e "${STATUSDIR_ROOT}$rtype/.meta.sh" || return
  done
}

sd_fsdir_new () # Name
{
  name=$(filestripext "$1" | tr -cd 'a-z0-9')
  local prefvar=${name}_prefix suffvar=${name}_suffix extvar=${name}_ext

  pref="${!prefvar-}"
  test -z "$pref" || pref=${pref}-
  suff="${!suffvar-}"
  test -z "$suff" || suff=-${suff}
  ext="${!extvar:-"tab"}"
  new=1
}

# Test if entry exists and set rtype
sd_fsdir_rtype () # Name
{
  set -- $(grep -l "^${1}_ext=" ${STATUSDIR_ROOT}*/.meta.sh)
  test $# -eq 1 -a -n "${1-}" || return
  rtype=$(basename $(dirname $1))
}

sd_fsdir_entry_validate ()
{
  test -e "$p/$k" && {
    ttl=${ttl:-$STATUSDIR_EXPIRY_AGE}
    local ttl_str mtime=$(filemtime $p/$k) mtime_str
    ttl_str=$( shell_cached fmtdate_relative "" $ttl "" )
    mtime_str=$( shell_cached fmtdate_relative "$mtime" "" "" )
    newer_than "$p/$k" "$ttl" && {

      # TODO: actually validate file
      #ck_md5 $p/$k;
      #ck_sha1 $p/$k;
      #ck_sha2 $p/$k;
      #ck_sha2_alt $p/$k;
      #sha1sum $p/$k;
      #md5sum $p/$k;
      #filemtime $p/$k;
      $LOG ok "" "Up-to-date" "$k: $mtime_str"
    } || {
      $LOG error "" "Stale file" "$k: $mtime_str > $ttl_str"
      return 1
    }
  } || {

    $LOG warn "" "Missing" "$p/$k"
    return 2
  }
}

sd_fsdir_deinit() # Record-Type
{
  test -d "$STATUSDIR_ROOT" || {
    $LOG "warn" "" "Statusdir is not initialized" ""
    return
  }
  local rtype; for rtype in $types
  do
    # TODO: refuse to cleanup non-empty dir
    find "${STATUSDIR_ROOT}$rtype" -type -f -not -name .meta.sh

    test ! -e "${STATUSDIR_ROOT}$rtype/.meta.sh" || {
      rm "${STATUSDIR_ROOT}$rtype/.meta.sh"
    }
    test ! -e "${STATUSDIR_ROOT}$rtype" || {
      rm -r "${STATUSDIR_ROOT}$rtype"
    }
  done
}

# Set metadata
sd_fsdir_set () # ATTR NAME VAL
{
  test $# -eq 3 && {
    fnmatch "* *" "$3" && set -- $1 $2 "\"$3\""
    grep -q '^'$2'_'$1'=' $l && {
      sed -i 's#^'$2'_'$1'=.*$#'$2'_'$1'='"$3"'#' $l
    } || {
      printf "%s_%s=%s\n" $2 $1 "$3" >>$l
    }
    return $?
  }
  test $# -eq 2 && {
    fnmatch "* *" "$2" && set -- $1 "\"$2\""
    grep -q '^'$1'=' $g && {
      sed -i 's#^'$1'=.*$#'$1'='"$2"'#' $g
    } || {
      printf "%s=%s\n" $1 "$2" >>$g
    }
    return $?
  }
}

# Check global rtype metadata
sd_fsdir_check () # NAME VAL
{
  local varname=$1 varttl=${1}_ttl
  shift
  test ${!varname:-1} "$@" && {
    newer_than "$g" ${!varttl:-$STATUSDIR_CHECK_TTL}
  }
}

statusdir_fsdir_lib_load ()
{
  Statusdir__backend_types["fsdir"]=FSDir
  true "${statusdir_fsdirs:=".meta/stat .statusdir"}"
  LUP=$(cwd_lookup_path $statusdir_fsdirs)
}

class.Statusdir.FSDir () # Instance-Id Message-Name Arguments...
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- $1 .default
  local name=Statusdir.FSDir
  local self="class.$name $1 " id=$1 m=$2
  shift 2

  local types="${fsd_types-"log index tree cache"}"
  local rtype="${fsd_rtype-"tree"}"

  case "$m" in
    .$name ) Statusdir__params[$id]="$*" ;;

    .default | \
    .info )
        echo "class.$name <#$id> ${Statusdir__params[$id]}"
      ;;

    .* )
        local l g c r p= k="${1-}" ttl="${2-}" v="${3-}" time=$(date +'%s')
        sd_fsdir_settings &&
        local pref name suff ext new init &&
        sd_fsdir_inner "${m:1}" "$@"
      ;;

    * )
        $LOG error "" "No such endpoint '$m' on" "$($self.info)" 1
      ;;
  esac
}

has_next_arg ()
{
  test $# -gt 0 -a "${1-}" != "--"
}

has_no_arg ()
{
  test $# -eq 0 -o "${1-}" = "--"
}

#
