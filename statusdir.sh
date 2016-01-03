#!/bin/sh
statusdir_source=$_

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

statusdir_root()
{
	path=$STATUSDIR_ROOT
	[ -e "$path" ] || mkdir -p $path
	echo $path
}

# Make path in statusdir exists, args are pathelems
# echos path
statusdir_assert()
{
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"tree/"$tree
	mkdir -p $path
	echo $path
	#export statusdir_tree=$tree
}

# As statusdir_assert, but last arg is filename
# (does not touch file, but echos it)
statusdir_assert_dir()
{
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"index/"$tree
	mkdir -p $(dirname $path)
	echo $path
}

# Specific statusdir_dir assert for .list file
statusdir_index()
{
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"index/"$tree".list"
	mkdir -p $(dirname $path)
	echo $path
}

statusdir_file()
{
	tree="$(echo "$@" | tr ' ' '/')"
	path=$STATUSDIR_ROOT"index/"$tree
	statusdir_assert_dir "$path" >/dev/null
	echo $path
}


### Main

# Ignore login console interpreter
case "$0" in "" ) ;; "-*" ) ;; * )

  # Ignore 'load-ext' sub-command

  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"

  case "$1" in load-ext ) ;; * )

      scriptname=statusdir
      # Do something if script invoked as '$scriptname.sh'
      base=$(basename $0 .sh)
      case "$base" in

        $scriptname )

            statusdir_load

            # invoke with function name first argument,
            func="$1"
            type "statusdir_$func" &>/dev/null && { func="statusdir_$1"; }
            type $func &>/dev/null && {
              shift 1
              $func "$@"
            } || exit 1

          ;;


      esac ;;

  esac ;;

esac

