#!/bin/sh

# Statusdir - a property store for bash with lightweight backends

# Does not store actual properties yet, and the tree files are not actually used.
# The files in the index are used to store lists of keys, see env.sh

set -eu

version=0.0.4-dev # script-mpe


statusdir_subcmd_load()
{
  statusdir_lib_start
}

statusdir_subcmd_unload()
{
  statusdir_lib_finish
}


# Subcommands

statusdir__info()
{
  export verbosity=4
  "$0" version
  note "Root:"
  "$0" root
  note "Backends:"
  "$0" backends
  note "List:"
  "$0" list
}


statusdir_man_1__root='Echo statusdir store location'
statusdir__root()
{
  test -n "$STATUSDIR_ROOT" || return 14
  path=$STATUSDIR_ROOT
  [ -e "$path" ] || mkdir -p $path
  echo $path
}


statusdir_man_1__backends='List backends available and online'
statusdir__backends()
{
  for bn in $scriptpath/statusdir-*.sh
  do
    sd_be_name=$(basename $bn .lib.sh | cut -d '-' -f 2)
    . $bn
    test -n "$sd_be_name" || error "Backend name expected ($(basename "$bn"))"
    $sd_be_name ping && note "$sd_be_name found" || warn "No $sd_be_name backend"
  done
}
statusdir_als__bes=backends


statusdir_man_1__backend="Print current backend's name. See 'be' to invoke it
directly. "
statusdir__backend()
{
  $sd_be backend
}

statusdir_man_1__assert="echos path. Default index is 'tree'."
statusdir_spc__assert="assert <rtype> [<index-name-id>]"
statusdir__assert()
{
  statusdir_assert "$@"
}

# As statusdir__assert, but last arg is filename
# (does not touch file, but echos it)
statusdir__assert_dir()
{
  test -n "${STATUSDIR_ROOT-}" || return 64
  local tree path
  tree="$(echo "$@" | tr ' ' '/')"
  path=$STATUSDIR_ROOT$tree
  test -d $path || mkdir -vp $(dirname $path)
  echo $path
}

statusdir__record()
{
  statusdir_record "$@"
}

statusdir__index()
{
  statusdir_index "$@"
}

statusdir__index_file()
{
  statusdir_index_file "$@"
}

# XXX: deprecate for index/index-file
statusdir__file()
{
  test -n "$STATUSDIR_ROOT" || return 66
  tree="$(echo "$@" | tr ' ' '/')"
  trueish "$assert_dir" && case "$tree" in */* ) ;;
        * ) statusdir__assert_dir "$@" >/dev/null ;;
      esac
  echo $STATUSDIR_ROOT"index/$tree"
}

# Create and cat properties file ($format $1)
statusdir__properties()
{
    echo statusdir__properties
  (
    props=$(statusdir__file "$1.properties")
    # XXX: initialize file sd_be=properties
    #statusdir.sh assert-

    test -n "$format" || format=properties
    case "$format" in
      properties )
          cat $props
        ;;
      sh )
          read_nix_style_file $props | properties2sh -
        ;;
    esac
  )
}



# XXX

# XXX: get some plumping commands to deal with embedded structures
# at paths.

# Assert given value exists at path in state.json
# arg: 1:jspath 2:value
statusdir__assert_json()
{
  # FIXME assert-json
  sf=$(statusdir__file "state.json" || return $?)
  test -s "$sf" || echo '{}' >$sf
  test -n "$1" || { echo $sf; return; }
  echo "$@" | tr ' ' '\n' | jsotk.py update $sf.tmp $sf || {
    echo "statusdir assert-json: Error reading $sf. " 1>&2
    return 1
  }
  test -s "$sf.tmp" && mv $sf.tmp $sf || {
    test -s "$sf" && {
      echo "statusdir assert-json: Error updating $sf with '$@'. " 1>&2
    }
  }
}

# Merge another json into state.json
# arg: 1:filepath 2:root-jspath
statusdir__cons_json()
{
  local status_json="$(statusdir__assert_json)" tmpf=$(setup_tmpf .json)
  jsotk.py merge $tmpf $status_json $1 || {
    rm $tmpf
    return 1
  }
  mv $tmpf $status_json
  echo $status_json
}

statusdir__ping()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  $sd_be ping || return $?
}

statusdir__load()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  $sd_be load || return $?
}

statusdir__unload()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  $sd_be unload || return $?
}

statusdir__list()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be list $1 || return $?
}

statusdir__get()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be get $1 || return $?
}

statusdir__set()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "value expected" 1
  test -n "${3-}" || set -- "$1" "$2" 0
  test $# -eq 3 -a -z "${4-}" || error "surplus arguments '$4'" 1
  $sd_be set "$1" "$3" "$2" || return $?
}

# FIXME: statusdir_als__delete=del
statusdir__del()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be del $1 || return $?
}

statusdir__incr()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || set -- "$1" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be incr $1 $2 || return $?
}

statusdir__decr()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || set -- "$1" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be decr "$@" || return $?
}

statusdir__exists()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be exists "$1" || return $?
}

statusdir__has()
{
  $sd_be has "$@" || return $?
}

statusdir__members()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be members "$1" || return $?
}

statusdir__add()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "member expected" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be add "$@" || return $?
}

statusdir__rem()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "member expected" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be rem "$@" || return $?
}


statusdir__be()
{
  test -n "${1-}" || error "cmd expected" 1
  $sd_be "$@"
}

statusdir__x()
{
  test -n "${1-}" || error "cmd expected" 1
  $sd_be x "$@"
}


# Generic subcmd's

statusdir_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
statusdir_load__help=f
statusdir_spc__help='-h|help [ID]'
statusdir__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
  rm_failed || return
}
statusdir_als___h=help
statusdir_als__commands=help


statusdir_man_1__version="Version info"
statusdir__version()
{
  echo "script-mpe:$scriptname/$version"
}
statusdir_als___V=version
statusdir_als____version=version


statusdir_man_1__edit='Edit this script and files'
statusdir_spc__edit='-e|edit [FILES]'
statusdir__edit()
{
  $EDITOR $0 $(which $base.sh) "$@"
}
statusdir_als___e=edit



# Script main functions

### Main

statusdir_main()
{
  test -n "${verbosity-}" || verbosity=5
  local scriptname=$(basename $0 .sh) base=statusdir \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" subcmd=

  INIT_LOG=$LOG
  true "${script_util:="$scriptpath/tools/sh"}"
  statusdir_main_init || exit $?
  shell_lib_init || return
  unset INIT_LOG

  case "$scriptname" in $base | sd )

        statusdir_main_lib || exit 2$?
        statusdir_subcmd_load || exit 1$?
        main_subcmd_run "$@" || exit 0$?
      ;;

    * )
        error "$scriptname: not a frontend for $base"
      ;;
  esac
}

statusdir_main_usage()
{
    cat <<EOM
statusdir.sh - Wrapper for simple access to memory store and DB services.

Usage:
    statusdir <cmd> [<args>..]

EOM
}

statusdir_main_init()
{
  test -n "$script_util" || return 103 # NOTE: sanity
  test -n "$scriptpath" || return
  local scriptname_old=$scriptname; export scriptname=statusdir-main-init

  true "${sd_be:="fsdir"}"
  CWD=$scriptpath

  #init-log\ ucache\ scriptpath\ std
  INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std" \
  INIT_LIB=" os sys str src shell log logger-std logger-theme main meta shell str-htd std stdio" \
      . $scriptpath/tools/main/init.sh || return

  # -- statusdir box init sentinel --
  export scriptname=$scriptname_old
}

statusdir_main_lib()
{
  test -z "$__load_lib" || return 14
  local __load_lib=1
  lib_load box date statusdir notify
  # -- statusdir box lib sentinel --
  set --
}

# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "${__load_lib-}" || {
    statusdir_main "$@"
  }
;; esac
