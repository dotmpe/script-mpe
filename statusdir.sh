#!/bin/sh
statusdir__source=$_

# Statusdir - a property store for bash with lightweight backends

# Does not store actual properties yet, and the tree files are not actually used.
# The files in the index are used to store lists of keys, see env.sh

set -e

version=0.0.4-dev # script-mpe


statusdir_load()
{
  test -z "$STATUSDIR_ROOT" && {
      STATUSDIR_ROOT="$HOME/.statusdir/"
  } || {
      fnmatch "*/" "$STATUSDIR_ROOT" || STATUSDIR_ROOT="$STATUSDIR_ROOT/"
  }
  export STATUSDIR_ROOT

  # Get temporary dir
  test -n "$sd_tmp_dir" || sd_tmp_dir=$(setup_tmpd $base)
  test -n "$sd_tmp_dir" -a -d "$sd_tmp_dir" || error "sd_tmp_dir load" 1

  # Detect backend

  test -n "$sd_be" || {
    which redis-cli >/dev/null 2>&1 &&
      redis-cli ping >/dev/null 2>&1 &&
        sd_be=redis
  }

  test -n "$sd_be" || {
    which membash >/dev/null 2>&1 && sd_be=membash
  }

  # Set default be
  test -n "$sd_be" || sd_be=fsdir

  # Load backend
  lib_load statusdir-$sd_be
  test -n "$sd_be_name" && sd_be=$sd_be_name
}

statusdir_unload()
{
  test -n "$sd_tmp_dir" || error "sd_tmp_dir unload" 1
  # XXX: quick check for cruft. Is triggering on empty directories.
  #test "$(echo $sd_tmp_dir/*)" = "$sd_tmp_dir/*" \
  #  || warn "Leaving temp files in $sd_tmp_dir: $(echo $sd_tmp_dir/*)"
  unset sd_be sd_tmp_dir
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

statusdir_man_1__assert="echos path. Default index is 'default'."
statusdir_spc__assert="assert <path-expr> [<index-name-id>]"
statusdir__assert()
{
  test -n "$STATUSDIR_ROOT" || error "STATUSDIR_ROOT" 1
  test -n "$1" || set -- status.json "$2"
  test -n "$2" || set -- "$1" default
  case "$2" in default )
      path=$STATUSDIR_ROOT/$1
    ;;
    * )
      path=$STATUSDIR_ROOT/$2/$1
    ;;
  esac
  path=$(normalize_relative $path)
  test -d $(dirname $path) \
    || mkdir -vp $(dirname $path)
  echo $path
}

# Make path in statusdir exists, args are pathelems
# echos path.
statusdir__assert_elems()
{
  test -n "$STATUSDIR_ROOT" || return 60
  tree="$(echo "$@" | tr ' ' '/')"
  path=$STATUSDIR_ROOT"tree/"$tree
  mkdir -vp $path
  echo $path
  #export statusdir__tree=$tree
}

# As statusdir__assert, but last arg is filename
# (does not touch file, but echos it)
statusdir__assert_dir()
{
  test -n "$STATUSDIR_ROOT" || return 64
  tree="$(echo "$@" | tr ' ' '/')"
  path=$STATUSDIR_ROOT$tree
  mkdir -vp $(dirname $path)
  echo $path
}

# Specific statusdir__dir assert for .list file
statusdir__index_file()
{
  test -n "$STATUSDIR_ROOT" || return 65
  tree="$(echo "$@" | tr ' ' '/')"
  echo $STATUSDIR_ROOT"index/$tree.list"
}

statusdir__index()
{
  cat $(statusdir__index_file "$@")
}

# XXX: deprecate for index/index-file
statusdir__file()
{
  test -n "$STATUSDIR_ROOT" || return 66
  tree="$(echo "$@" | tr ' ' '/')"
  case "$tree" in *\* ) ;; * )
    statusdir__assert_dir "$@" >/dev/null
  esac
  echo $STATUSDIR_ROOT"index/$tree"
}

# Create and cat properties file ($format $1)
statusdir__properties()
{
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
  $sd_be ping $1 || return $?
}

statusdir__list()
{
  $sd_be list "$@"
}

statusdir__get()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  $sd_be get $1 || return $?
}

statusdir__set()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || error "value expected" 1
  test -n "$3" || set -- "$1" "$2" 0
  test -z "$4" || error "surplus arguments '$4'" 1
  $sd_be set "$1" "$3" "$2" || return $?
}

# FIXME: statusdir_als__delete=del
statusdir__del()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  $sd_be del $1 || return $?
}

statusdir__incr()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || set -- "$1" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  $sd_be incr $1 $2 || return $?
}

statusdir__decr()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || set -- "$1" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  $sd_be decr "$@" || return $?
}

statusdir__exists()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments '$3'" 1
  $sd_be exists "$1" || return $?
}

statusdir__has()
{
  test -n "$1" -a -n "$2" || error "key/member expected" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  $sd_be has "$@" || return $?
}

statusdir__members()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments '$3'" 1
  $sd_be members "$1" || return $?
}

statusdir__add()
{
  test -n "$1" -a -n "$2" || error "key/member expected" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  $sd_be add "$@" || return $?
}

statusdir__rem()
{
  test -n "$1" -a -n "$2" || error "key/member expected" 1
  test -z "$3" || error "surplus arguments '$3'" 1
  $sd_be rem "$@" || return $?
}


statusdir__be()
{
  test -n "$1" || error "cmd expected" 1
  $sd_be "$@"
}

statusdir__x()
{
  test -n "$1" || error "cmd expected" 1
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
#statusdir_als___V=version
#statusdir_als____version=version


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
  test -n "$verbosity" || verbosity=5
  local scriptname=$(basename $0 .sh) base=statusdir \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" subcmd= \
    sd_tmpdir=

  statusdir_init || exit $?

  case "$scriptname" in $base | sd )

        statusdir_lib || exit $?
        main_run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base"
      ;;
  esac
}

statusdir_usage()
{
    cat <<EOM
statusdir.sh - Wrapper for simple access to memory store and DB services.

Usage:
    statusdir <cmd> [<args>..]

EOM
}

statusdir_init()
{
  test -n "$scriptpath" || return
  export SCRIPTPATH=$scriptpath
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/log.sh
  util_mode=ext . $scriptpath/util.sh
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load box date
  # -- statusdir box init sentinel --
}

statusdir_lib()
{
  test -z "$__load_lib" || return 14
  local __load_lib=1
  # -- statusdir box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -n "$__load_lib" || {
    case "$1" in load-ext ) ;; * )
      statusdir_main "$@"
    ;; esac
  }
;; esac
