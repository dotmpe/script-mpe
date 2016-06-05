#!/bin/sh
statusdir__source=$_

# Statusdir - a lightweight property store for bash

# Does not store actual properties yet, and the tree files are not actually used.
# The files in the index are used to store lists of keys, see env.sh

set -e


statusdir_load()
{
  [ -z "$STATUSDIR_ROOT" ] && {
      STATUSDIR_ROOT="$(echo ~/.statusdir/)"
      #export STATUSDIR_ROOT
  }

  # Load backend
  test -n "$be" || { which membash 2>&1 >/dev/null && be=membash; }
  test -n "$be" || be=fsdir

  test ! -e "$scriptdir/statusdir_$be.sh" || {
    . $scriptdir/statusdir_$be.sh
  }

}

statusdir_unload()
{
  noop
}


statusdir__root()
{
  test -n "$STATUSDIR_ROOT" || return 12
	path=$STATUSDIR_ROOT
	[ -e "$path" ] || mkdir -p $path
	echo $path
}


statusdir__reset()
{
  test ! -e $1 || { rm $1 || return $?; }
}

statusdir__exists()
{
  test -s $1 || return $?
}

statusdir__dump()
{
  test ! -e $1 || cat $1
}

# echos path. Default index is 'default'.
# assert <path-expr> [<index-name-id>]
statusdir__assert()
{
  test -n "$STATUSDIR_ROOT" || error "STATUSDIR_ROOT" 1
  test -n "$1" || set -- status.json "$2"
  test -n "$2" || set -- "$1" default
  case "$2" in default )
      path=$STATUSDIR_ROOT/$1
    ;;
    * )
      path=$STATUSDIR_ROOT/bases/$2/$1
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
  test -n "$STATUSDIR_ROOT" || return 13
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"tree/"$tree
	mkdir -p $path
	echo $path
	#export statusdir__tree=$tree
}

# As statusdir__assert, but last arg is filename
# (does not touch file, but echos it)
statusdir__assert_dir()
{
  test -n "$STATUSDIR_ROOT" || return 14
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"index/"$tree
	mkdir -vp $(dirname $path)
	echo $path
}

# Specific statusdir__dir assert for .list file
statusdir__index()
{
  test -n "$STATUSDIR_ROOT" || return 15
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"index/"$tree".list"
	mkdir -p $(dirname $path)
	echo $path
}

statusdir__file()
{
  test -n "$STATUSDIR_ROOT" || return 16
  tree="$(echo "$@" | tr ' ' '/')"
  case "$tree" in *\* ) ;; * )
    statusdir__assert_dir "$@" >/dev/null
  esac
  echo $STATUSDIR_ROOT"index/$tree"
}


# XXX: get some plumping commands to deal with embedded structures
# at paths.

# Assert given value exists at path in state.json
# arg: 1:jspath 2:value
statusdir__assert_state()
{
  sf=$(statusdir__file "state.json" || return $?)
  test -s "$sf" || echo '{}' >$sf
  test -n "$1" || { echo $sf; return; }
  echo "$@" | tr ' ' '\n' | jsotk.py update $sf.tmp $sf || {
    echo "statusdir assert-state: Error reading $sf. "
    return 1
  }
  mv $sf.tmp $sf
}

# Merge another json into state.json
# arg: 1:filepath 2:root-jspath
statusdir__cons_json()
{
  status_json="$(statusdir__assert_state)"
  jsotk.py merge /tmp/new-status.json $status_json $1
  mv /tmp/new-status.json $status_json
}



statusdir__get()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments" 1
  $be get $1 || return $?
}

statusdir__set()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || error "value expected" 1
  test -n "$3" || set -- "$1" "$2" 0
  test -z "$4" || error "surplus arguments" 1
  $be set $1 $3 $2 || return $?
}

statusdir__del()
{
  test -n "$1" || error "key expected" 1
  test -z "$2" || error "surplus arguments" 1
  $be delete $1 || return $?
}

statusdir__incr()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || set -- "$1" 1
  test -z "$3" || error "surplus arguments" 1
  $be incr $1 $2 || return $?
}

statusdir__decr()
{
  test -n "$1" || error "key expected" 1
  test -n "$2" || set -- "$1" 1
  test -z "$3" || error "surplus arguments" 1
  $be decr $1 $2 || return $?
}



### Main

statusdir__main()
{
  local scriptname=statusdir base=$(basename $0 .sh) verbosity=5 \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)"

  statusdir__init || exit $?

  case "$base" in $scriptname )

        statusdir__lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base"
      ;;
  esac
}

statusdir__init()
{
  test -n "$scriptdir"
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/box.init.sh
  box_run_sh_test
  . $scriptdir/htd.lib.sh
  . $scriptdir/main.sh
  . $scriptdir/main.init.sh
  . $scriptdir/box.lib.sh
  . $scriptdir/date.lib.sh
  # -- statusdir box init sentinel --
}

statusdir__lib()
{
  local __load_lib=1
  # -- statusdir box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    statusdir__main "$@"
  ;; esac
;; esac

