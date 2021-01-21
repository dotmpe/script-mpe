#!/usr/bin/env bash

sd_fsdir()
{
  local types="${fsd_types-"log index tree cache"}"
  local rtype="${fsd_rtype-"tree"}"
  local l g c r p= k="${2-}" ttl= v="${4-}" time=$(date +'%s')
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

      stat ) has_no_arg "$@" || break
          sd_fsdir_check sd_fsdir_status -le 1 && {
            test $sd_fsdir_status -eq 0 &&
              $LOG ok "" "Status OK, age: $(file_modification_age "$g")" ||
              $LOG done "" "Status $sd_fsdir_status, age: $(file_modification_age "$g")"
          } || {
            $LOG fail "" "Stale status $sd_fsdir_status, age: $(file_modification_age "$g")"
          }
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
            local entry_cnt=0 invalid_cnt=0
            while has_next_arg "$@"
            do incr entry_cnt; sd_fsdir_entry_load "$1" && {
                    sd_fsdir_entry_validate || { r=$?
                        test $r -le ${sd_fsdir_status:-0} || sd_fsdir_status=$r
                        incr invalid_cnt
                    }
                }
                shift
            done ; unset r
            local max_age="$( shell_cached \
                fmtdate_relative "" "${!varttl:-$STATUSDIR_CHECK_TTL}" "")"
            test $sd_fsdir_status -eq 0 &&
              $LOG ok "" "Status OK, just refreshed from $entry_cnt entries (max-age $max_age)" ||
              $LOG done "" "Status $sd_fsdir_status, just refreshed from $entry_cnt entries, $invalid_cnt failed (max-age $max_age)"
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
          sd_fsdir_entry_load "$@" || return
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
      index ) # [prefvar=$1_name_prefix] [extvar=$1_extension] ~ Local-Name [Exists]
          { not_falseish "${2-}" || test -e "${STATUSDIR_ROOT}$rtype/$k"
          } || {
            $LOG error "" "No such $rtype '$1'" "${STATUSDIR_ROOT}$rtype/$k"
            return 2
          }

          # Normally report local entry
          test ${local:-1} -eq 1 && {
            local LUP=$(statusdir_lookup_path)
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

      path )
          echo "${STATUSDIR_ROOT}$rtype/$k"
        ;;

      attr ) has_next_arg "$@" || return
          sd_fsdir_attr "$@" || return
          while has_next_arg "$@"; do shift; done
        ;;

      exec )
          has_next_arg "$@" && {
            rtype=$1; shift; c=0
            sd_fsdir_entry_load "$@" || return
            shift $c
          }
          has_next_seq "$@" && shift || true
          sd_fsdir_exec "$@" || return
          while has_next_arg "$@"; do shift; done
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

# Load meta for all types?
sd_fsdir_settings ()
{
  g=${STATUSDIR_ROOT}meta.sh
  local rtype
  for rtype in $types
  do . ${STATUSDIR_ROOT}$rtype/.meta.sh || return
  done
}

sd_fsdir_entry_load () # NAME [TTL [META]]
{
  test $# -gt 0 || return 98
  local n=$#; name=$1; shift
  has_next_arg "$@" && { ttl=$1; shift; }
  while has_next_arg "$@"
  do meta="${meta-}${meta+ }$1"; shift
  done
  c=$(( $n - $# ))

  sd_fsdir_load "$name" "${ttl-}" "${meta-}" || return
  p=$STATUSDIR_ROOT$rtype
  l=$p/.meta.sh
  k=$pref$name$suff.$ext
}

sd_fsdir_load () # NAME [TTL [META]]
{
  new= ; p= ; k= ; pref= ; suff=
  sd_fsdir_existing "$1" || {
    test ${init:-0} -eq 1 && {
      $LOG note "" "New" "$1"
    } || {
      $LOG error "" "cannot create" "$1"
      return 1
    }
    test -n "$ttl" || ttl="\$_1DAY"
    sd_fsdir_new "$1" || {
      $LOG error "" "cannot create" "$1"
      return 1
    }
    init=
  }

  test $# -lt 3 && return
  shift 2
  test ${new:-0} -eq 0 || return 0
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

sd_fsdir_attr ()
{
  local varname
  while has_next_arg "$@"
  do
    varname=${name}_$1
    echo ${!varname}
    shift
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

  true "${rtype:="shell"}"
  l=$STATUSDIR_ROOT$rtype/.meta.sh
  $LOG note "" "New" "$rtype/$pref$name$suff.$ext"
  touch $STATUSDIR_ROOT$rtype/$pref$name$suff.$ext
  sd_fsdir_set ext $name $ext
  #test -z "$pref" || sd_fsdir_set $name pref ${pref:1}
  #test -z "$suff" || sd_fsdir_set $name suff ${suff:1}
  test -z "${ttl-}" || sd_fsdir_set ttl $name "$ttl"
  test -z "${meta-}" || sd_fsdir_set meta $name "$meta"
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
      ttl_str=$( shell_cached fmtdate_relative "" $ttl "" )
      $LOG error "" "Stale file" "$k: $mtime_str > $ttl_str"
      return 1
    }
  } || {

    $LOG warn "" "Missing" "$p/$k"
    return 2
  }
}

sd_fsdir_exec () # [Cmd-Line]
{
  local outf cmdl execdir ret
  cmdl=$(sd_fsdir_attr cmd 2>/dev/null)
  test ${new:-0} -eq 0 && {
    test $# -eq 0 -o "$*" = "$cmdl" || cmdl="$*"
  } ||
    cmdl="$*"
  execdir=$(sd_fsdir_attr pwd 2>/dev/null)
  test -n "$execdir" || execdir="$PWD"
  test -n "$rtype" || return 11
  outf="${STATUSDIR_ROOT}$rtype/$k"

  { ( cd "$execdir" && eval "$cmdl" ) || ret=$?
  } > "$outf.stdout" 2> "$outf.stderr"

  sd_fsdir_set cmd "$name" "$cmdl"
  sd_fsdir_set ret "$name" "$ret"
  test ! -s "$outf.stderr" || cat "$outf.stderr"
  test ${ret:0} -ne 0 || {
    sd_fsdir_${rtype}_update "$outf.stdout" || return
  }
  rm "$outf.stdout" "$outf.stderr"
}

sd_fsdir_deinit () # Record-Type
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
sd_fsdir_set () # ATTR [NAME] VAL
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

# Check with global fsdir metadata mtime (g: ~/.statusdir/meta.sh)
sd_fsdir_check () # NAME VAL
{
  local varname=$1 varttl=${1}_ttl
  shift
  test ${!varname:-1} "$@" && {
    newer_than "$g" ${!varttl:-$STATUSDIR_CHECK_TTL}
  }
}

# TODO: auto-merge files
sd_fsdir_index_update ()
{ true
}

sd_fsdir_log_update ()
{ true
}

sd_fsdir_cache_update ()
{ true
}

statusdir_fsdir_lib_init ()
{
  #test ${ctx_statusdir_lib_init:-1} -eq 0 ||
  #test ${ctx_class_lib_init:-1} -eq 0 ||
  #    error "StatusDir:FSDir requires @Statusdir@Class" 1

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

has_next_seq ()
{
  test "${1-}" = "--"
}

#
