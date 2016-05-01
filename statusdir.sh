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

# Make path in statusdir exists, args are pathelems
# echos path
statusdir__assert()
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
	mkdir -p $(dirname $path)
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

# Assert given value exists at path in state.json
# arg: 1:jspath 2:value
statusdir__assert_json()
{
  sf=$(statusdir__file "state.json" || return $?)
  test -s "$sf" || echo '{}' >$sf
  test -n "$1" || { echo $sf; return; }
  echo "$@" | tr ' ' '\n' | jsotk.py update $sf.tmp $sf
  mv $sf.tmp $sf
}

# Merge another json into state.json
# arg: 1:filepath 2:root-jspath
statusdir__cons_json()
{
  status_json="$(statusdir__assert_json)"
  jsotk.py merge /tmp/new-status.json $status_json $1
  mv /tmp/new-status.json $status_json
}


### Main

statusdir__main()
{
  local scriptname=statusdir base=$(basename $0 .sh) verbosity=5

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
  test -n "$LIB" || LIB=$HOME/bin
  . $LIB/std.lib.sh
  . $LIB/str.lib.sh
  . $LIB/os.lib.sh
  . $LIB/util.sh
  . $LIB/box.init.sh
  box_run_sh_test
  . $LIB/htd.lib.sh
  . $LIB/main.sh
  . $LIB/main.init.sh
  . $LIB/box.lib.sh
  . $LIB/date.lib.sh
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

