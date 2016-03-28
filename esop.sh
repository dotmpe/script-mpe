#!/bin/sh
esop_src="$_"

set -e

set -o posix


version=0.0.0+20150911-0659 # script.mpe


esop_man_1__version="Version info"
esop__version()
{
  echo "$(cat $PREFIX/bin/.app-id)/$version"
}
esop_als__V=version


esop_man_1__x=abc
esop_run__x=abc
esop_spc__x="x [ARG..]"
esop__x()
{
  note "Running x"
}

esop_main()
{
  test -n "$esop_src" || return

  local LIB="$(dirname $esop_src)"

  esop_init || return $?
  #return $(( $? - 1 ))
  local scriptname=esop base="$(basename $esop_src ".sh")"
  #\ verbosity=7
  #choice_debug=1
  debug "Init ok"
  case "$base" in
    $scriptname )
      run_subcmd "$@" || return $?
      ;;
    * )
      error "not a frontend for $base" 1
      ;;
  esac
}

esop_init()
{
  . $LIB/main.sh
  . $LIB/std.lib.sh
  . $LIB/str.lib.sh
  . $LIB/util.sh
  . $LIB/box.init.sh
  box_run_sh_test
  # -- esop box init sentinel --
}

esop_load()
{
  local __load_lib=1
  . $LIB/match.sh load-ext
  # -- esop box load sentinel --
}


#echo 0=$0 esop_src=$esop_src 1=$1 2=$2
test "$esop_src" != "$0" && {
  set -- load-ext
}
case "$1" in "." | "source" )
  esop_src=$2
  set -- load-ext
;; esac

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )
    esop_main "$@" || exit $?
  ;; esac
;; esac
